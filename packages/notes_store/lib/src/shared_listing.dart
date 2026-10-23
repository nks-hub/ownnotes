import 'package:drift/drift.dart';
import 'package:notes_protocol/notes_protocol.dart';
import 'package:uuid/uuid.dart';
import 'database.dart';

final _noteFile = RegExp(r'\.(md|txt)$', caseSensitive: false);

/// Notes inside the Notes folder retain their REST route and share identity.
Future<void> refreshSharedNotes(
  NotesDatabase database,
  SharingClient sharing,
  String accountId, {
  required Future<void> Function() keepLease,
}) async {
  await keepLease();
  final received = await sharing.sharedWithMe();
  await keepLease();
  ShareTargets? outgoing;
  try {
    outgoing = await sharing.sharedTargets();
  } on Object {
    // Optional outgoing badges must not block incoming DAV synchronization.
  }
  await database.recordSharing(
    accountId,
    incoming: ShareTargets(
      fileIds: received.where((s) => !s.isFolder).map((s) => s.fileId).toSet(),
      folderPaths: received.where((s) => s.isFolder).map((s) => s.path).toSet(),
    ),
    outgoing: outgoing,
  );
  final incoming = <int, IncomingShare>{};
  for (final share in received) {
    if (share.isFolder || !_noteFile.hasMatch(share.path)) continue;
    final previous = incoming[share.fileId];
    if (previous == null || (!previous.canEdit && share.canEdit)) {
      incoming[share.fileId] = share;
    }
  }
  final rows =
      await (database.select(database.localNotes)..where(
            (n) => n.accountId.equals(accountId) & n.remoteId.isNotNull(),
          ))
          .get();
  final viaNotes = {
    for (final n in rows)
      if (n.kind == 'note') n.remoteId!,
  };
  final byFile = {
    for (final n in rows)
      if (n.kind == 'shared') n.remoteId!: n,
  };
  final wanted = <int>{};
  for (final share in incoming.values) {
    if (viaNotes.contains(share.fileId)) continue;
    if (!wanted.add(share.fileId)) continue;
    final row = byFile[share.fileId];
    if (row != null) {
      await (database.update(
        database.localNotes,
      )..where((n) => n.id.equals(row.id))).write(
        LocalNotesCompanion(
          davPath: Value(share.path),
          readonly: Value(!share.canEdit),
          sharedByMe: outgoing == null
              ? const Value.absent()
              : Value(outgoing.contains(share.fileId, share.path)),
        ),
      );
      continue;
    }
    await keepLease();
    final file = await sharing.read(share.path);
    final name = share.path.split('/').last.replaceAll(_noteFile, '');
    await database
        .into(database.localNotes)
        .insert(
          LocalNotesCompanion.insert(
            id: const Uuid().v4(),
            accountId: accountId,
            remoteId: Value(share.fileId),
            title: name,
            content: file.content,
            readonly: Value(!share.canEdit),
            etag: Value(file.etag),
            baseContent: Value(file.content),
            baseTitle: Value(name),
            baseCategory: const Value(''),
            baseFavorite: const Value(false),
            syncState: const Value('clean'),
            kind: const Value('shared'),
            sharedWithMe: const Value(true),
            sharedByMe: Value(outgoing?.contains(share.fileId, share.path)),
            davPath: Value(share.path),
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );
  }
  for (final row in byFile.values) {
    if (wanted.contains(row.remoteId)) continue;
    await (database.delete(
      database.localNotes,
    )..where((n) => n.id.equals(row.id) & n.syncState.equals('clean'))).go();
  }
}
