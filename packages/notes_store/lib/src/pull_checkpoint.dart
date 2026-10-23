import 'dart:convert';
import 'package:drift/drift.dart';
import 'database.dart';

extension PullCheckpointStorage on NotesDatabase {
  Future<PullCheckpoint?> pullCheckpoint(String accountId) => (select(
    pullCheckpoints,
  )..where((c) => c.accountId.equals(accountId))).getSingleOrNull();

  Future<Set<int>> storedRemoteIds(
    String accountId, {
    bool notesOnly = false,
  }) async {
    final rows =
        await (selectOnly(localNotes)
              ..addColumns([localNotes.remoteId])
              ..where(
                localNotes.accountId.equals(accountId) &
                    localNotes.remoteId.isNotNull() &
                    (notesOnly
                        ? localNotes.kind.equals('note')
                        : const Constant(true)),
              ))
            .get();
    return rows.map((r) => r.read(localNotes.remoteId)!).toSet();
  }

  /// Partial pulls may change cached text, so their old ETag cannot be reused.
  /// The older watermark still permits replaying all changes since that baseline.
  Future<void> invalidateListEtag(String accountId) =>
      (update(pullCheckpoints)..where((c) => c.accountId.equals(accountId)))
          .write(const PullCheckpointsCompanion(listEtag: Value(null)));

  Future<bool> canReuseList(PullCheckpoint checkpoint) => transaction(() async {
    final current = await pullCheckpoint(checkpoint.accountId);
    final a = await account(checkpoint.accountId);
    if (current != checkpoint ||
        a == null ||
        a.generation != checkpoint.generation ||
        a.mutationEpoch != checkpoint.epoch) {
      return false;
    }
    try {
      final ids = (jsonDecode(checkpoint.remoteIds) as List)
          .cast<int>()
          .toSet();
      return (await storedRemoteIds(a.id)).containsAll(ids);
    } on FormatException {
      return false;
    } on TypeError {
      return false;
    }
  });

  Future<void> finishPull({
    required Account started,
    required Set<int> ids,
    required String? scope,
    required bool scopeKnown,
    required int? watermark,
    required String? etag,
    required int? etagPruneBefore,
    bool applyCensus = true,
  }) => transaction(() async {
    final a = await account(started.id);
    if (a == null ||
        a.mutationEpoch != started.mutationEpoch ||
        a.generation != started.generation) {
      return;
    }
    if (applyCensus) await census(a.id, a.mutationEpoch, ids, scope: scope);
    // A skipped dirty row may not contain the server text represented by this
    // checkpoint. Keep the older baseline until those rows can be reconciled.
    final unresolved =
        await (select(localNotes)
              ..where(
                (n) =>
                    n.accountId.equals(a.id) &
                    n.kind.equals('note') &
                    n.remoteId.isNotNull() &
                    (n.syncState.equals('clean').not() |
                        n.unreadable.equals(true) |
                        n.missingSince.isNotNull()),
              )
              ..limit(1))
            .get();
    if (!scopeKnown ||
        watermark == null ||
        watermark < 0 ||
        unresolved.isNotEmpty) {
      return;
    }
    await into(pullCheckpoints).insertOnConflictUpdate(
      PullCheckpointsCompanion.insert(
        accountId: a.id,
        epoch: a.mutationEpoch,
        generation: a.generation,
        scope: Value(scope),
        watermark: watermark,
        listEtag: Value(etag),
        etagPruneBefore: Value(etagPruneBefore),
        remoteIds: jsonEncode(ids.toList()),
      ),
    );
  });
}
