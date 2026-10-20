import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show InsertMode, Value;
import 'package:flutter/services.dart';
import 'package:notes_store/notes_store.dart';

import '../attachments/attachment_service.dart';
import 'capture_store.dart';

/// The platform's inbox of shares. Android and iOS keep every share in a
/// folder of their own until [ack] says the app stored it.
abstract interface class CaptureSource {
  Future<List<NativeCapture>> list();
  Future<void> ack(String id);
}

final class ChannelCaptureSource implements CaptureSource {
  const ChannelCaptureSource();
  static const channel = MethodChannel('com.nkshub.nextcloudnotes/share');

  @override
  Future<List<NativeCapture>> list() async {
    final raw = await channel.invokeListMethod<Map<Object?, Object?>>(
      'listCaptures',
    );
    return [for (final m in raw ?? const []) NativeCapture.fromMap(m)];
  }

  @override
  Future<void> ack(String id) => channel.invokeMethod<void>('ackCapture', id);
}

/// iOS: the share extension writes one folder per share into the App Group
/// container (`captures/<id>/capture.json` plus `files/<n>`); the app reads
/// and removes them directly.
final class GroupFolderCaptureSource implements CaptureSource {
  const GroupFolderCaptureSource(this.root);
  final Directory root;

  static final _safeId = RegExp(r'^[A-Za-z0-9_-]{1,80}$');

  @override
  Future<List<NativeCapture>> list() async {
    if (!await root.exists()) return const [];
    final out = <NativeCapture>[];
    await for (final dir in root.list()) {
      final id = dir.uri.pathSegments.lastWhere((s) => s.isNotEmpty);
      if (dir is! Directory || !_safeId.hasMatch(id)) continue;
      try {
        final json =
            jsonDecode(await File('${dir.path}/capture.json').readAsString())
                as Map<String, Object?>;
        out.add(
          NativeCapture.fromMap({
            ...json,
            'files': [
              for (final f in json['files']! as List<Object?>)
                if (f is Map) {...f, 'path': '${dir.path}/files/${f['file']}'},
            ],
          }),
        );
      } on Object {
        // Written whole or not at all; an unreadable folder is skipped.
      }
    }
    return out..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  @override
  Future<void> ack(String id) async {
    if (!_safeId.hasMatch(id)) return;
    final dir = Directory('${root.path}/$id');
    if (await dir.exists()) await dir.delete(recursive: true);
  }
}

/// Moves every delivery from the platform inbox into [store], and only then
/// acknowledges it. A capture that fails to store is left in the inbox and
/// the error is rethrown after the others were handled. Returns how many
/// were new.
Future<int> drainCaptures(CaptureSource source, CaptureStore store) async {
  var received = 0;
  Object? failure;
  for (final capture in await source.list()) {
    try {
      if (await store.ingest(capture)) received++;
      await source.ack(capture.id);
    } on Object catch (e) {
      failure ??= e;
    }
  }
  if (failure != null) throw failure;
  return received;
}

/// Where a capture goes.
sealed class CaptureTarget {
  const CaptureTarget();
}

final class NewNote extends CaptureTarget {
  const NewNote({this.category = ''});
  final String category;
}

final class AppendTo extends CaptureTarget {
  const AppendTo(this.noteId);
  final String noteId;
}

/// Turns [capture] into local data and forgets it. Safe to run again after a
/// crash at any point: the note takes the capture's id and attached files are
/// staged under ids derived from it.
///
/// Returns the id of the note that holds the content.
Future<String> convertCapture({
  required NotesDatabase database,
  required AttachmentService attachments,
  required CaptureStore store,
  required Capture capture,
  required String accountId,
  required CaptureTarget target,
}) async {
  if (await database.account(accountId) == null) {
    throw StateError('account_missing');
  }
  final text = capture.text.trim();
  var noteId = capture.id;
  var appended = false;
  if (target is AppendTo) {
    appended = await _append(database, accountId, target.noteId, text);
    if (appended) noteId = target.noteId;
  }
  if (!appended) {
    final title = capture.title.trim().isNotEmpty
        ? capture.title.trim()
        : text.isNotEmpty
        ? titleFromContent(text)
        : capture.files.firstOrNull?.name ?? '';
    await database
        .into(database.localNotes)
        .insert(
          LocalNotesCompanion.insert(
            id: capture.id,
            accountId: accountId,
            title: title,
            content: text,
            category: Value(target is NewNote ? target.category : ''),
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          ),
          mode: InsertMode.insertOrIgnore,
        );
    noteId = capture.id;
  }
  for (var i = 0; i < capture.files.length; i++) {
    final f = capture.files[i];
    await attachments.stage(
      id: '${capture.id}-$i',
      accountId: accountId,
      noteId: noteId,
      source: File(f.path),
      name: f.name,
      mime: f.mime,
    );
  }
  await store.complete(capture.id);
  unawaited(attachments.flush(accountId).then((_) {}, onError: (_) {}));
  return noteId;
}

/// Adds [text] to the end of a note. False when the note cannot take it
/// (gone, read-only, changing under us); the caller then makes a new note so
/// the text is not lost.
Future<bool> _append(
  NotesDatabase db,
  String accountId,
  String noteId,
  String text,
) async {
  for (var attempt = 0; attempt < 3; attempt++) {
    final note = await db.note(accountId, noteId);
    if (note == null || note.readonly) return false;
    if (text.isEmpty || note.content.trimRight().endsWith(text)) {
      return true; // Nothing to add, or a crashed earlier run added it.
    }
    final body = note.content.trimRight();
    try {
      await db.saveDraft(
        accountId: accountId,
        id: noteId,
        revision: note.revision,
        title: note.title,
        content: body.isEmpty ? text : '$body\n\n$text',
        category: note.category,
        favorite: note.favorite,
      );
      return true;
    } on StateError catch (e) {
      if (e.message != 'local_revision_changed') return false;
    }
  }
  return false;
}
