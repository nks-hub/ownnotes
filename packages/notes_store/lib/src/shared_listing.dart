import 'package:drift/drift.dart';
import 'package:notes_protocol/notes_protocol.dart';
import 'package:uuid/uuid.dart';
import 'database.dart';
import 'notes_pull.dart';

final _noteFile = RegExp(r'\.(md|txt)$', caseSensitive: false);

/// Notes inside the Notes folder retain their REST route and share identity.
Future<bool> refreshSharedNotes(
  NotesDatabase database,
  SharingClient sharing,
  String accountId, {
  required Future<void> Function() keepLease,
  required NotesPullSnapshot snapshot,
}) async {
  final notesApiIds = snapshot.ids;
  Future<bool> current() async {
    final account = await database.account(accountId);
    return account?.mutationEpoch == snapshot.account.mutationEpoch &&
        account?.generation == snapshot.account.generation;
  }

  await keepLease();
  final received = await sharing.sharedWithMe();
  final discovered = await sharing.discoverSharedNotes(
    received,
    beforeRequest: keepLease,
    notesApiIds: notesApiIds,
  );
  await keepLease();
  ShareTargets? outgoing;
  try {
    outgoing = await sharing.sharedTargets();
  } on Object {
    // Optional outgoing badges must not block incoming DAV synchronization.
  }
  if (!await current()) return false;
  Future<LocalNote?> byFile(int id) =>
      (database.select(database.localNotes)..where(
            (n) => n.accountId.equals(accountId) & n.remoteId.equals(id),
          ))
          .getSingleOrNull();
  final wanted = {...notesApiIds};
  for (final share in discovered) {
    if (notesApiIds.contains(share.fileId)) continue;
    if (!wanted.add(share.fileId)) continue;
    final row = await byFile(share.fileId);
    if (row != null) {
      final applied = await database.transaction(() async {
        if (!await current()) return false;
        final fresh = await byFile(share.fileId);
        if (fresh == null || fresh.id != row.id) return false;
        await (database.update(database.localNotes)..where(
              (n) => n.id.equals(row.id) & n.remoteId.equals(share.fileId),
            ))
            .write(
              LocalNotesCompanion(
                davPath: Value(share.path),
                kind: const Value('shared'),
                remotePath: const Value(null),
                missingSince: const Value(null),
                sharedWithMe: const Value(true),
                etag: fresh.kind == 'note'
                    ? const Value(null)
                    : const Value.absent(),
                readonly: Value(!share.writable),
                sharedByMe: outgoing == null
                    ? const Value.absent()
                    : Value(outgoing.contains(share.fileId, share.path)),
              ),
            );
        return true;
      });
      if (!applied) return false;
      continue;
    }
    await keepLease();
    final file = await sharing.read(share.path);
    final name = share.path.split('/').last.replaceAll(_noteFile, '');
    final applied = await database.transaction(() async {
      if (!await current() || await byFile(share.fileId) != null) return false;
      await database
          .into(database.localNotes)
          .insert(
            LocalNotesCompanion.insert(
              id: const Uuid().v4(),
              accountId: accountId,
              remoteId: Value(share.fileId),
              title: name,
              content: file.content,
              readonly: Value(!share.writable),
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
      return true;
    });
    if (!applied) return false;
  }
  return database.transaction(() async {
    if (!await current()) return false;
    await database.recordSharing(
      accountId,
      incoming: ShareTargets(
        fileIds: received
            .where((s) => !s.isFolder)
            .map((s) => s.fileId)
            .toSet(),
        folderPaths: received
            .where((s) => s.isFolder)
            .map((s) => s.path)
            .toSet(),
      ),
      outgoing: outgoing,
    );
    final removed =
        await (database.select(database.localNotes)..where(
              (n) =>
                  n.accountId.equals(accountId) &
                  n.kind.equals('shared') &
                  n.remoteId.isNotIn(wanted) &
                  n.syncState.equals('clean'),
            ))
            .get();
    for (final row in removed) {
      await database.keepCopy(row, 'removed', reason: 'missing_on_server');
      await (database.delete(
        database.localNotes,
      )..where((n) => n.id.equals(row.id))).go();
    }
    return true;
  });
}
