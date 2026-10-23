import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:notes_protocol/notes_protocol.dart';
import 'package:notes_store/notes_store.dart';

import 'attachment_cache.dart';
import 'attachment_markdown.dart';
import 'staging.dart';

/// What happened to one upload attempt.
sealed class UploadOutcome {
  const UploadOutcome();
}

/// On the server; [markdown] is the reference to put into the note.
final class Uploaded extends UploadOutcome {
  const Uploaded(this.markdown);
  final String markdown;
}

/// The note has no server id yet; the file stays staged for later.
final class WaitingForNote extends UploadOutcome {
  const WaitingForNote();
}

/// The file stays staged as failed with this short [code].
final class UploadFailed extends UploadOutcome {
  const UploadFailed(this.code);
  final String code;
}

/// Stages files, uploads them with retries and puts the references into
/// notes. Everything that was accepted survives a restart in [staging].
final class AttachmentService {
  AttachmentService({
    required this.database,
    required this.staging,
    required this.cache,
    required this.clientFor,
    this.retryDelays = const [Duration(seconds: 2), Duration(seconds: 6)],
  });

  final NotesDatabase database;
  final AttachmentStaging staging;
  final AttachmentCache cache;
  final Future<AttachmentsClient> Function(Account account) clientFor;

  /// Pauses between the attempts of one upload; the list length is the number
  /// of retries.
  final List<Duration> retryDelays;

  final _busy = <String>{};
  final _heldForEditor = <String>{};
  Future<void>? _recovered;

  Future<void> _ready() => _recovered ??= staging.recoverInterrupted();

  Future<StagedAttachment> stage({
    required String accountId,
    required String noteId,
    required File source,
    required String name,
    String? mime,
    String? id,
    bool holdForEditor = false,
  }) async {
    await _ready();
    final clean = safeAttachmentName(name);
    final itemId =
        id ?? DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    if (holdForEditor) _heldForEditor.add(itemId);
    try {
      return await staging.stage(
        id: itemId,
        accountId: accountId,
        noteId: noteId,
        name: clean,
        mime: mime ?? mimeForName(clean),
        source: source,
      );
    } catch (_) {
      _heldForEditor.remove(itemId);
      rethrow;
    }
  }

  /// A new process has no holds; its next flush recovers unconfirmed links.
  void releaseEditorHold(String id) => _heldForEditor.remove(id);

  Future<List<StagedAttachment>> pending(
    String accountId,
    String noteId,
  ) async {
    await _ready();
    return staging.list(accountId: accountId, noteId: noteId);
  }

  /// Uploads one staged file. The result is stored before this returns, so a
  /// crash afterwards loses neither the file nor its server path.
  Future<UploadOutcome> upload(String id) async {
    await _ready();
    if (!_busy.add(id)) return const UploadFailed('busy');
    try {
      return await _upload(id);
    } finally {
      _busy.remove(id);
    }
  }

  Future<UploadOutcome> _upload(String id) async {
    final loaded = await staging.get(id);
    if (loaded == null) return const UploadFailed('missing');
    StagedAttachment item = loaded;
    if (item.state == StagedState.uploaded && item.remotePath != null) {
      return Uploaded(
        attachmentMarkdown(item.remotePath!, image: item.isImage),
      );
    }
    final note = await database.note(item.accountId, item.noteId);
    if (note == null) return _fail(item, 'note_gone');
    final remoteId = note.remoteId;
    if (remoteId == null) return const WaitingForNote();
    final account = await database.account(item.accountId);
    if (account == null) return _fail(item, 'note_gone');

    item = item.copyWith(state: StagedState.uploading, clearError: true);
    await staging.update(item);
    var attempt = 0;
    while (true) {
      try {
        final client = await clientFor(account);
        final file = staging.dataFile(id);
        final done = await client.upload(
          remoteId,
          fileName: item.name,
          content: file.openRead(),
          length: item.size,
        );
        item = item.copyWith(
          state: StagedState.uploaded,
          remotePath: done.path,
          clearError: true,
        );
        await staging.update(item);
        // Keep the picture for offline previews; a full cache is no failure.
        try {
          await cache.write(
            account.id,
            remoteId,
            done.path,
            await file.readAsBytes(),
          );
        } on Object {
          /* Preview cache only. */
        }
        return Uploaded(attachmentMarkdown(done.path, image: item.isImage));
      } on StateError {
        return _fail(item, 'auth');
      } on NotesHttpException catch (e) {
        final code = _httpCode(e.statusCode);
        if (code != 'server' || attempt >= retryDelays.length) {
          return _fail(item, code);
        }
      } on Object {
        // Offline, timeout or an unreadable receipt: the server may or may
        // not hold the file; a retry can leave a second copy there.
        if (attempt >= retryDelays.length) return _fail(item, 'offline');
      }
      await Future<void>.delayed(retryDelays[attempt++]);
    }
  }

  static String _httpCode(int status) => switch (status) {
    401 || 403 => 'denied',
    404 => 'note_gone',
    413 => 'too_large',
    _ => 'server',
  };

  Future<UploadOutcome> _fail(StagedAttachment item, String code) async {
    await staging.update(item.copyWith(state: StagedState.failed, error: code));
    return UploadFailed(code);
  }

  /// The reference went into the note; the staged copy is no longer needed.
  Future<void> complete(String id) => staging.remove(id);

  /// Forgets a staged file. The reference, if any, stays in the note.
  Future<void> discard(String id) => staging.remove(id);

  /// Uploads what is waiting for [accountId] and appends the references of
  /// everything on the server but not yet in its note. Call after a sync.
  /// Failed items wait for an explicit retry, except network failures.
  Future<int> flush(String accountId) async {
    await _ready();
    var moved = 0;
    for (final item in await staging.list(accountId: accountId)) {
      if (_busy.contains(item.id) || _heldForEditor.contains(item.id)) continue;
      final retriable =
          item.state == StagedState.stored ||
          (item.state == StagedState.failed && item.error == 'offline');
      if (retriable) await upload(item.id);
    }
    final byNote = <String, List<StagedAttachment>>{};
    for (final item in await staging.list(accountId: accountId)) {
      if (item.state == StagedState.uploaded &&
          item.remotePath != null &&
          !_busy.contains(item.id) &&
          !_heldForEditor.contains(item.id)) {
        byNote.putIfAbsent(item.noteId, () => []).add(item);
      }
    }
    for (final entry in byNote.entries) {
      if (await _appendReferences(accountId, entry.key, entry.value)) {
        moved += entry.value.length;
      }
    }
    return moved;
  }

  Future<bool> _appendReferences(
    String accountId,
    String noteId,
    List<StagedAttachment> items,
  ) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      final note = await database.note(accountId, noteId);
      if (note == null) {
        for (final i in items) {
          await staging.remove(i.id);
        }
        return false;
      }
      final missing = <String>[];
      for (final item in items) {
        final md = attachmentMarkdown(item.remotePath!, image: item.isImage);
        if (!note.content.contains(md)) missing.add(md);
      }
      try {
        if (missing.isNotEmpty) {
          final body = note.content.trimRight();
          await database.saveDraft(
            accountId: accountId,
            id: noteId,
            revision: note.revision,
            title: note.title,
            content: body.isEmpty
                ? missing.join('\n')
                : '$body\n\n${missing.join('\n')}',
            category: note.category,
            favorite: note.favorite,
          );
        }
        for (final item in items) {
          await staging.remove(item.id);
        }
        return true;
      } on StateError catch (e) {
        // A newer local revision appeared meanwhile: read it and try again.
        if (e.message != 'local_revision_changed') return false;
      }
    }
    return false;
  }

  /// Upload already clears the error while holding the file's busy guard.
  Future<UploadOutcome> retry(String id) => upload(id);

  /// Whether the account's server can delete attachments (Notes 6.1+).
  Future<bool> canDelete(String accountId) async {
    final account = await database.account(accountId);
    if (account == null) return false;
    try {
      return (await clientFor(account)).route.canDelete;
    } on Object {
      return false;
    }
  }

  /// Deletes the file on the server. Notes that still link to it will show a
  /// missing file; removing the reference is a separate edit of the note.
  Future<void> deleteRemote(String accountId, int remoteId, String path) async {
    final account = await database.account(accountId);
    if (account == null) throw StateError('account_missing');
    await (await clientFor(account)).delete(remoteId, path);
    await cache.forget(accountId, remoteId, path);
  }

  /// Bytes for a preview: the cache, else the server. Works offline for
  /// anything seen before; any file type is allowed.
  Future<Uint8List> load(LocalNote note, String path) async {
    final remoteId = note.remoteId;
    if (remoteId == null) throw StateError('note_not_on_server');
    return cache.load(note.accountId, remoteId, path, () async {
      final account = await database.account(note.accountId);
      if (account == null) throw StateError('account_missing');
      return (await (await clientFor(account)).download(remoteId, path)).bytes;
    });
  }

  Future<bool> isCached(LocalNote note, String path) async =>
      note.remoteId != null &&
      await cache.contains(note.accountId, note.remoteId!, path);
}
