import 'package:drift/drift.dart';
import 'package:notes_protocol/notes_protocol.dart';
import 'package:uuid/uuid.dart';
part 'database.g.dart';

class Accounts extends Table {
  TextColumn get id => text()();
  TextColumn get server => text()();
  TextColumn get loginName => text()();
  TextColumn get credentialRef => text().unique()();
  TextColumn get state =>
      text().withDefault(const Constant('capabilitiesPending'))();
  IntColumn get generation => integer().withDefault(const Constant(1))();
  IntColumn get mutationEpoch => integer().withDefault(const Constant(0))();
  @override
  Set<Column<Object>> get primaryKey => {id};
}

class LocalNotes extends Table {
  TextColumn get id => text()();
  TextColumn get accountId =>
      text().references(Accounts, #id, onDelete: KeyAction.cascade)();
  IntColumn get remoteId => integer().nullable()();
  TextColumn get title => text()();
  TextColumn get content => text()();
  TextColumn get category => text().withDefault(const Constant(''))();
  BoolColumn get favorite => boolean().withDefault(const Constant(false))();
  BoolColumn get readonly => boolean().withDefault(const Constant(false))();
  IntColumn get revision => integer().withDefault(const Constant(1))();
  TextColumn get etag => text().nullable()();
  TextColumn get baseContent => text().nullable()();
  TextColumn get baseTitle => text().nullable()();
  TextColumn get baseCategory => text().nullable()();
  BoolColumn get baseFavorite => boolean().nullable()();
  TextColumn get syncState => text().withDefault(const Constant('draft'))();
  IntColumn get updatedAt => integer()();
  @override
  Set<Column<Object>> get primaryKey => {id};
  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {accountId, remoteId},
  ];
}

class Operations extends Table {
  TextColumn get id => text()();
  TextColumn get accountId =>
      text().references(Accounts, #id, onDelete: KeyAction.cascade)();
  TextColumn get noteId =>
      text().references(LocalNotes, #id, onDelete: KeyAction.cascade)();
  IntColumn get revision => integer()();
  TextColumn get kind => text()();
  TextColumn get state => text().withDefault(const Constant('queued'))();
  TextColumn get payload => text()();
  TextColumn get errorCode => text().nullable()();
  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(tables: [Accounts, LocalNotes, Operations])
class NotesDatabase extends _$NotesDatabase {
  NotesDatabase(super.executor);
  @override
  int get schemaVersion => 1;
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    beforeOpen: (_) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
  Stream<List<Account>> watchAccounts() => select(accounts).watch();
  Future<Account?> account(String id) =>
      (select(accounts)..where((a) => a.id.equals(id))).getSingleOrNull();
  Future<LocalNote?> note(String accountId, String id) =>
      (select(localNotes)
            ..where((n) => n.accountId.equals(accountId) & n.id.equals(id)))
          .getSingleOrNull();
  Stream<List<LocalNote>> watchNotes(String accountId) =>
      (select(localNotes)
            ..where(
              (n) =>
                  n.accountId.equals(accountId) &
                  n.syncState.isNotIn(['recoveryArchived', 'deleting']),
            )
            ..orderBy([(n) => OrderingTerm.desc(n.updatedAt)]))
          .watch();
  Future<String> createDraft(
    String accountId, {
    String title = '',
    String content = '',
    String category = '',
  }) => transaction(() async {
    if (await account(accountId) == null) throw StateError('account_missing');
    final id = const Uuid().v4();
    await into(localNotes).insert(
      LocalNotesCompanion.insert(
        id: id,
        accountId: accountId,
        title: title,
        content: content,
        category: Value(category),
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    return id;
  });

  /// Compare-and-swap prevents an old editor overwriting a newer local revision.
  Future<int> saveDraft({
    required String accountId,
    required String id,
    required int revision,
    required String title,
    required String content,
    required String category,
    required bool favorite,
  }) => transaction(() async {
    final current = await note(accountId, id);
    if (current == null) throw StateError('note_missing');
    if (current.readonly) throw StateError('note_readonly');
    if (current.syncState == 'recoveryArchived') {
      throw StateError('recovery_archived');
    }
    if (current.syncState == 'deleting') throw StateError('note_deleted');
    if (current.revision != revision) {
      throw StateError('local_revision_changed');
    }
    await (update(
      localNotes,
    )..where((n) => n.id.equals(id) & n.accountId.equals(accountId))).write(
      LocalNotesCompanion(
        title: Value(title),
        content: Value(content),
        category: Value(category),
        favorite: Value(favorite),
        revision: Value(revision + 1),
        syncState: Value(
          current.syncState == 'needsDecision' ? 'needsDecision' : 'draft',
        ),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
    return revision + 1;
  });

  /// A note never uploaded goes away at once; an uploaded one is hidden and
  /// waits for the next sync to delete it on the server.
  Future<void> markDeleted(String accountId, String id) =>
      transaction(() async {
        final current = await note(accountId, id);
        if (current == null) return;
        if (current.readonly) throw StateError('note_readonly');
        if (current.syncState == 'sending') throw StateError('note_sending');
        if (current.remoteId == null) {
          await (delete(localNotes)..where((n) => n.id.equals(id))).go();
          return;
        }
        // Undecided operations are superseded by the user's decision to delete.
        await (update(operations)..where(
              (o) =>
                  o.noteId.equals(id) & o.state.isNotIn(['done', 'dismissed']),
            ))
            .write(const OperationsCompanion(state: Value('dismissed')));
        await (update(localNotes)..where((n) => n.id.equals(id))).write(
          LocalNotesCompanion(
            syncState: const Value('deleting'),
            revision: Value(current.revision + 1),
          ),
        );
      });

  /// Removes synced notes the server no longer lists. Only clean rows go:
  /// local edits and pending deletions are never lost to a listing.
  Future<void> census(String accountId, int epoch, Set<int> remoteIds) =>
      transaction(() async {
        final a = await account(accountId);
        if (a == null || a.mutationEpoch != epoch) return;
        await (delete(localNotes)..where(
              (n) =>
                  n.accountId.equals(accountId) &
                  n.syncState.equals('clean') &
                  n.remoteId.isNotNull() &
                  n.remoteId.isNotIn(remoteIds),
            ))
            .go();
      });

  Future<int> readEpoch(String accountId) async {
    final a = await account(accountId);
    if (a == null) throw StateError('account_missing');
    return a.mutationEpoch;
  }

  /// Dirty drafts remain untouched, including when the remote is unreadable.
  /// Removal of notes deleted elsewhere is [census], after the last page.
  Future<bool> applyPull(
    String accountId,
    int epoch,
    List<NoteRecord> records,
  ) => transaction(() async {
    final a = await account(accountId);
    if (a == null || a.mutationEpoch != epoch) return false;
    for (final record in records) {
      if (record is! RemoteNote) continue;
      final existing =
          await (select(localNotes)..where(
                (n) =>
                    n.accountId.equals(accountId) &
                    n.remoteId.equals(record.id),
              ))
              .getSingleOrNull();
      if (existing != null && existing.syncState != 'clean') continue;
      final values = LocalNotesCompanion(
        title: Value(record.title),
        content: Value(record.content),
        category: Value(record.category),
        favorite: Value(record.favorite),
        readonly: Value(record.readonly),
        etag: Value(record.etag),
        baseContent: Value(record.content),
        baseTitle: Value(record.title),
        baseCategory: Value(record.category),
        baseFavorite: Value(record.favorite),
        syncState: const Value('clean'),
        updatedAt: Value(record.modified * 1000),
        revision: Value((existing?.revision ?? 0) + 1),
      );
      if (existing == null) {
        await into(localNotes).insert(
          values.copyWith(
            id: Value(const Uuid().v4()),
            accountId: Value(accountId),
            remoteId: Value(record.id),
          ),
        );
      } else {
        await (update(
          localNotes,
        )..where((n) => n.id.equals(existing.id))).write(values);
      }
    }
    return true;
  });
}
