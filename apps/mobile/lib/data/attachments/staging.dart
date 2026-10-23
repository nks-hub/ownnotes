import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Where a staged file is on its way to the server.
enum StagedState {
  /// Copied into app storage, waiting for its turn (or for the note to exist
  /// on the server).
  stored,
  uploading,

  /// On the server; the Markdown reference is not in the note yet.
  uploaded,
  failed,
}

/// Largest file the app copies into staging.
const maxStagedBytes = 64 * 1024 * 1024;

final class AttachmentTooLarge implements Exception {
  const AttachmentTooLarge();
  @override
  String toString() => 'AttachmentTooLarge';
}

/// One picked, captured or imported file bound to the draft it belongs to.
final class StagedAttachment {
  const StagedAttachment({
    required this.id,
    required this.accountId,
    required this.noteId,
    required this.name,
    required this.mime,
    required this.size,
    required this.createdAt,
    this.state = StagedState.stored,
    this.error,
    this.remotePath,
  });

  factory StagedAttachment.fromJson(Map<String, Object?> json) =>
      StagedAttachment(
        id: json['id']! as String,
        accountId: json['accountId']! as String,
        noteId: json['noteId']! as String,
        name: json['name']! as String,
        mime: json['mime']! as String,
        size: json['size']! as int,
        createdAt: json['createdAt']! as int,
        state: StagedState.values.byName(json['state']! as String),
        error: json['error'] as String?,
        remotePath: json['remotePath'] as String?,
      );

  final String id;
  final String accountId;

  /// Local note id of the draft; not the server id.
  final String noteId;
  final String name;
  final String mime;
  final int size;
  final int createdAt;
  final StagedState state;

  /// Short code of the last failure: `offline`, `auth`, `too_large`,
  /// `denied`, `note_gone`, `server`.
  final String? error;
  final String? remotePath;

  bool get isImage => mime.startsWith('image/');

  StagedAttachment copyWith({
    StagedState? state,
    String? error,
    bool clearError = false,
    String? remotePath,
  }) => StagedAttachment(
    id: id,
    accountId: accountId,
    noteId: noteId,
    name: name,
    mime: mime,
    size: size,
    createdAt: createdAt,
    state: state ?? this.state,
    error: clearError ? null : error ?? this.error,
    remotePath: remotePath ?? this.remotePath,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'accountId': accountId,
    'noteId': noteId,
    'name': name,
    'mime': mime,
    'size': size,
    'createdAt': createdAt,
    'state': state.name,
    'error': error,
    'remotePath': remotePath,
  };
}

/// Files copied into app storage before anything is reported as accepted.
///
/// Each file lives in `<root>/<id>/data` with `meta.json` next to it; the
/// metadata is written last and replaced atomically, so a crash leaves
/// either a complete entry or a folder that is ignored and cleaned up.
final class AttachmentStaging {
  AttachmentStaging(this.root);

  final Directory root;
  final _changes = StreamController<void>.broadcast();

  /// Fires after every change; listeners reload with [list].
  Stream<void> get changes => _changes.stream;

  File dataFile(String id) => File('${root.path}/$id/data');
  File _meta(String id) => File('${root.path}/$id/meta.json');

  /// Copies [source] into staging. Staging the same [id] again returns the
  /// entry that exists, so a repeated delivery adds nothing.
  Future<StagedAttachment> stage({
    required String id,
    required String accountId,
    required String noteId,
    required String name,
    required String mime,
    required File source,
  }) async {
    final existing = await get(id);
    if (existing != null) return existing;
    final size = await source.length();
    if (size > maxStagedBytes) throw const AttachmentTooLarge();
    final dir = Directory('${root.path}/$id');
    if (await dir.exists()) await dir.delete(recursive: true);
    await dir.create(recursive: true);
    await source.copy('${dir.path}/data');
    final item = StagedAttachment(
      id: id,
      accountId: accountId,
      noteId: noteId,
      name: name,
      mime: mime,
      size: size,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _write(item);
    return item;
  }

  Future<StagedAttachment?> get(String id) async {
    final meta = _meta(id);
    try {
      if (!await meta.exists() || !await dataFile(id).exists()) return null;
      return StagedAttachment.fromJson(
        jsonDecode(await meta.readAsString()) as Map<String, Object?>,
      );
    } on Object {
      return null;
    }
  }

  Future<void> update(StagedAttachment item) => _write(item);

  /// Entries of one draft, oldest first; all entries when [noteId] is null.
  /// Strict reads reject unreadable entries before automatic draft deletion.
  Future<List<StagedAttachment>> list({
    String? accountId,
    String? noteId,
    bool strict = false,
  }) async {
    if (!await root.exists()) {
      if (strict &&
          await FileSystemEntity.type(root.path) !=
              FileSystemEntityType.notFound) {
        throw StateError('attachment_storage_unreadable');
      }
      return const [];
    }
    final items = <StagedAttachment>[];
    await for (final entry in root.list()) {
      if (entry is! Directory) continue;
      final id = entry.uri.pathSegments.lastWhere((s) => s.isNotEmpty);
      final item = await get(id);
      if (item == null) {
        if (strict && await entry.exists()) {
          throw StateError('attachment_metadata_unreadable');
        }
        continue;
      }
      if ((accountId == null || item.accountId == accountId) &&
          (noteId == null || item.noteId == noteId)) {
        items.add(item);
      }
    }
    return items..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  /// Run once per process start: nothing is uploading any more, and a copy
  /// interrupted before its metadata was written was never accepted.
  Future<void> recoverInterrupted() async {
    if (await root.exists()) {
      await for (final entry in root.list()) {
        if (entry is Directory &&
            !await File('${entry.path}/meta.json').exists()) {
          await entry.delete(recursive: true);
        }
      }
    }
    for (final item in await list()) {
      if (item.state == StagedState.uploading) {
        await update(item.copyWith(state: StagedState.stored));
      }
    }
  }

  Future<void> remove(String id) async {
    final dir = Directory('${root.path}/$id');
    if (await dir.exists()) await dir.delete(recursive: true);
    _changes.add(null);
  }

  /// Drops everything of an account (account removal).
  Future<void> removeAccount(String accountId) async {
    for (final item in await list(accountId: accountId)) {
      await remove(item.id);
    }
  }

  Future<void> _write(StagedAttachment item) async {
    final tmp = File('${root.path}/${item.id}/meta.json.tmp');
    await tmp.writeAsString(jsonEncode(item.toJson()), flush: true);
    await tmp.rename(_meta(item.id).path);
    _changes.add(null);
  }
}
