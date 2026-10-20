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

  /// `note` is listed by the Notes API; `shared` is a file somebody shared
  /// with the account, outside its Notes folder, synced over WebDAV at
  /// [davPath]. [remoteId] of a shared note is its file id, [etag] the WebDAV
  /// entity tag.
  TextColumn get kind => text().withDefault(const Constant('note'))();
  TextColumn get davPath => text().nullable()();

  /// Category of the last failed attempt to delete the note on the server
  /// (`offline`, `auth`, `server`, ...); null while nothing failed.
  TextColumn get deleteError => text().nullable()();

  /// The server could not hand out this note's text on the last pull; the
  /// stored copy may be stale.
  BoolColumn get unreadable => boolean().nullable()();

  /// When a pull stopped listing the note although the sync scope may have
  /// changed. The row is kept until the owner decides.
  IntColumn get missingSince => integer().nullable()();
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

/// Which coordinator (app or background worker) may send for an account.
class SyncLeases extends Table {
  TextColumn get accountId =>
      text().references(Accounts, #id, onDelete: KeyAction.cascade)();
  TextColumn get owner => text()();
  IntColumn get expiresAt => integer()();
  @override
  Set<Column<Object>> get primaryKey => {accountId};
}

/// What the last sync passes of an account found; survives a restart.
@DataClassName('SyncStatusRow')
class SyncStatuses extends Table {
  TextColumn get accountId =>
      text().references(Accounts, #id, onDelete: KeyAction.cascade)();

  /// End of the last pass that reached the server.
  IntColumn get lastCheckedAt => integer().nullable()();

  /// `offline`, `auth`, `locked`, `storage_full` or `server`.
  TextColumn get problem => text().nullable()();
  IntColumn get problemAt => integer().nullable()();

  /// Fingerprint of what the server lists for the account (Notes folder).
  TextColumn get scope => text().nullable()();
  @override
  Set<Column<Object>> get primaryKey => {accountId};
}

/// Text kept off to the side until the owner discards it: the two versions
/// of a conflict, a note deleted here, a note the server stopped listing.
/// No foreign key to the note, a copy outlives its row.
@DataClassName('RecoveryCopy')
class RecoveryCopies extends Table {
  TextColumn get id => text()();
  TextColumn get accountId =>
      text().references(Accounts, #id, onDelete: KeyAction.cascade)();
  TextColumn get noteId => text().nullable()();
  IntColumn get remoteId => integer().nullable()();

  /// `device`, `server`, `deleted` or `removed`.
  TextColumn get kind => text()();
  TextColumn get title => text()();
  TextColumn get content => text()();
  TextColumn get category => text().withDefault(const Constant(''))();
  BoolColumn get favorite => boolean().withDefault(const Constant(false))();
  TextColumn get etag => text().nullable()();
  TextColumn get reason => text().nullable()();
  IntColumn get createdAt => integer()();
  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Account-level sync state for the status row and sheet.
final class AccountSyncStatus {
  const AccountSyncStatus({
    this.lastCheckedAt,
    this.problem,
    this.pendingUploads = 0,
    this.decisions = 0,
    this.pendingDeletions = 0,
    this.failedDeletions = 0,
    this.unreadable = 0,
    this.missing = 0,
  });

  /// When a pass last reached the server; null before the first one.
  final DateTime? lastCheckedAt;

  /// `offline`, `auth`, `locked`, `storage_full`, `server` or null.
  final String? problem;
  final int pendingUploads;
  final int decisions;

  /// Deletions waiting for the server, failed ones included.
  final int pendingDeletions;
  final int failedDeletions;
  final int unreadable;
  final int missing;

  /// Everything the owner may have to act on.
  int get needsAttention => decisions + failedDeletions + unreadable + missing;
}

@DriftDatabase(
  tables: [
    Accounts,
    LocalNotes,
    Operations,
    SyncLeases,
    SyncStatuses,
    RecoveryCopies,
  ],
)
class NotesDatabase extends _$NotesDatabase {
  NotesDatabase(super.executor);
  @override
  int get schemaVersion => 4;
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) await m.createTable(syncLeases);
      if (from < 3) {
        await m.addColumn(localNotes, localNotes.kind);
        await m.addColumn(localNotes, localNotes.davPath);
      }
      if (from < 4) {
        await m.createTable(syncStatuses);
        await m.createTable(recoveryCopies);
        await m.addColumn(localNotes, localNotes.deleteError);
        await m.addColumn(localNotes, localNotes.unreadable);
        await m.addColumn(localNotes, localNotes.missingSince);
      }
    },
    beforeOpen: (_) async {
      await customStatement('PRAGMA foreign_keys = ON');
      // The app and a background worker may open the file at the same time.
      await customStatement('PRAGMA busy_timeout = 5000');
    },
  );

  /// Takes or extends the account's lease for [owner]. One statement, so two
  /// processes cannot both win. False while another owner's lease is valid.
  Future<bool> holdLease(String accountId, String owner, Duration ttl) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    try {
      final changed = await customUpdate(
        'INSERT INTO sync_leases (account_id, owner, expires_at) '
        'VALUES (?1, ?2, ?3) ON CONFLICT (account_id) DO UPDATE '
        'SET owner = excluded.owner, expires_at = excluded.expires_at '
        'WHERE sync_leases.owner = excluded.owner '
        'OR sync_leases.expires_at <= ?4',
        variables: [
          Variable.withString(accountId),
          Variable.withString(owner),
          Variable.withInt(now + ttl.inMilliseconds),
          Variable.withInt(now),
        ],
        updates: {syncLeases},
      );
      return changed > 0;
    } on Object {
      return false; // The account was removed meanwhile (foreign key).
    }
  }

  Future<void> releaseLease(String accountId, String owner) => (delete(
    syncLeases,
  )..where((l) => l.accountId.equals(accountId) & l.owner.equals(owner))).go();
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
    // The server lets a read-only note change its favorite star only.
    if (current.readonly &&
        (title != current.title ||
            content != current.content ||
            category != current.category)) {
      throw StateError('note_readonly');
    }
    if (current.syncState == 'recoveryArchived') {
      throw StateError('recovery_archived');
    }
    if (current.syncState == 'unreadable') throw StateError('note_unreadable');
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

  /// Like [saveDraft] for text that overlaps a change pulled meanwhile: the
  /// local text is kept and the note waits for the user's decision instead of
  /// being sent over the server's version.
  Future<int> saveConflict({
    required String accountId,
    required String id,
    required int revision,
    required String title,
    required String content,
    required String category,
    required bool favorite,
  }) => transaction(() async {
    final saved = await saveDraft(
      accountId: accountId,
      id: id,
      revision: revision,
      title: title,
      content: content,
      category: category,
      favorite: favorite,
    );
    await (update(localNotes)
          ..where((n) => n.id.equals(id) & n.accountId.equals(accountId)))
        .write(const LocalNotesCompanion(syncState: Value('needsDecision')));
    return saved;
  });

  /// A note never uploaded goes away at once; an uploaded one is hidden and
  /// waits for the next sync to delete it on the server.
  Future<void> markDeleted(String accountId, String id) =>
      transaction(() async {
        final current = await note(accountId, id);
        if (current == null) return;
        if (current.readonly) throw StateError('note_readonly');
        // A shared note leaves the list only by ending the share.
        if (current.kind == 'shared') throw StateError('note_shared');
        if (current.syncState == 'sending') throw StateError('note_sending');
        if (current.syncState != 'deleting') await keepCopy(current, 'deleted');
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
            deleteError: const Value(null),
            revision: Value(current.revision + 1),
          ),
        );
      });

  /// Cancels a deletion the server has not carried out yet. False when the
  /// note is not waiting for deletion any more. A request already on its way
  /// can still win; the note then ends as a server-deleted decision at its
  /// next upload and keeps its text.
  Future<bool> undoDelete(String accountId, String id) => transaction(() async {
    final current = await note(accountId, id);
    if (current == null || current.syncState != 'deleting') return false;
    await (update(localNotes)..where((n) => n.id.equals(id))).write(
      LocalNotesCompanion(
        syncState: const Value('draft'),
        deleteError: const Value(null),
        revision: Value(current.revision + 1),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
    await (delete(
      recoveryCopies,
    )..where((c) => c.noteId.equals(id) & c.kind.equals('deleted'))).go();
    return true;
  });

  /// Stores the note's text (or the given one) as a recovery copy, once per
  /// distinct text and kind. Returns the copy's id.
  Future<String> keepCopy(
    LocalNote note,
    String kind, {
    String? reason,
    String? title,
    String? content,
    String? category,
    bool? favorite,
    String? etag,
  }) async {
    final text = content ?? note.content;
    final name = title ?? note.title;
    final same =
        await (select(recoveryCopies)..where(
              (c) =>
                  c.accountId.equals(note.accountId) &
                  c.noteId.equals(note.id) &
                  c.kind.equals(kind) &
                  c.content.equals(text) &
                  c.title.equals(name),
            ))
            .getSingleOrNull();
    if (same != null) return same.id;
    final id = const Uuid().v4();
    await into(recoveryCopies).insert(
      RecoveryCopiesCompanion.insert(
        id: id,
        accountId: note.accountId,
        noteId: Value(note.id),
        remoteId: Value(note.remoteId),
        kind: kind,
        title: name,
        content: text,
        category: Value(category ?? note.category),
        favorite: Value(favorite ?? note.favorite),
        etag: Value(etag ?? note.etag),
        reason: Value(reason),
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    return id;
  }

  Stream<AccountSyncStatus> watchSyncStatus(String accountId) =>
      customSelect(
        'SELECT s.last_checked_at AS checked, s.problem AS problem, '
        '(SELECT COUNT(*) FROM local_notes n WHERE n.account_id = ?1 '
        "AND n.sync_state IN ('draft', 'sending')) AS pending, "
        '(SELECT COUNT(*) FROM local_notes n WHERE n.account_id = ?1 '
        "AND n.sync_state = 'needsDecision') AS decisions, "
        '(SELECT COUNT(*) FROM local_notes n WHERE n.account_id = ?1 '
        "AND n.sync_state = 'deleting') AS deleting, "
        '(SELECT COUNT(*) FROM local_notes n WHERE n.account_id = ?1 '
        "AND n.sync_state = 'deleting' AND n.delete_error IS NOT NULL) "
        'AS failed, '
        '(SELECT COUNT(*) FROM local_notes n WHERE n.account_id = ?1 '
        "AND (n.unreadable = 1 OR n.sync_state = 'unreadable')) AS unreadable, "
        '(SELECT COUNT(*) FROM local_notes n WHERE n.account_id = ?1 '
        'AND n.missing_since IS NOT NULL) AS missing '
        'FROM (SELECT 1) base LEFT JOIN sync_statuses s ON s.account_id = ?1',
        variables: [Variable.withString(accountId)],
        readsFrom: {syncStatuses, localNotes},
      ).watch().map((rows) {
        final row = rows.single;
        final checked = row.read<int?>('checked');
        return AccountSyncStatus(
          lastCheckedAt: checked == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(checked),
          problem: row.read<String?>('problem'),
          pendingUploads: row.read<int>('pending'),
          decisions: row.read<int>('decisions'),
          pendingDeletions: row.read<int>('deleting'),
          failedDeletions: row.read<int>('failed'),
          unreadable: row.read<int>('unreadable'),
          missing: row.read<int>('missing'),
        );
      });

  Future<AccountSyncStatus> syncStatus(String accountId) =>
      watchSyncStatus(accountId).first;

  /// Writes the outcome of a pass. [completed] moves the last-checked time;
  /// a null [problem] clears the stored one.
  Future<void> recordSyncResult(
    String accountId, {
    required bool completed,
    String? problem,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    try {
      await customUpdate(
        'INSERT INTO sync_statuses '
        '(account_id, last_checked_at, problem, problem_at) '
        'VALUES (?1, ?2, ?3, ?4) ON CONFLICT (account_id) DO UPDATE SET '
        'last_checked_at = COALESCE(excluded.last_checked_at, '
        'sync_statuses.last_checked_at), problem = excluded.problem, '
        'problem_at = excluded.problem_at',
        variables: [
          Variable.withString(accountId),
          Variable<int>(completed ? now : null),
          Variable<String>(problem),
          Variable<int>(problem == null ? null : now),
        ],
        updates: {syncStatuses},
      );
    } on Object {
      // The account was removed meanwhile (foreign key).
    }
  }

  /// Problems stored by earlier runs, by account.
  Future<Map<String, String>> storedProblems() async => {
    for (final s in await select(syncStatuses).get())
      if (s.problem != null) s.accountId: s.problem!,
  };

  /// Removes synced notes the server no longer lists. Only clean rows go:
  /// local edits and pending deletions are never lost to a listing, and every
  /// removed row leaves a recovery copy. When the sync [scope] (Notes folder)
  /// differs from the last pass, or the listing is empty although notes were
  /// synced, the server may simply be showing another folder: the rows stay,
  /// marked as missing, until the owner decides. Returns how many were kept
  /// that way.
  Future<int> census(
    String accountId,
    int epoch,
    Set<int> remoteIds, {
    String? scope,
  }) => transaction(() async {
    final a = await account(accountId);
    if (a == null || a.mutationEpoch != epoch) return 0;
    final stored = await (select(
      syncStatuses,
    )..where((s) => s.accountId.equals(accountId))).getSingleOrNull();
    final scopeChanged =
        scope != null && stored?.scope != null && stored!.scope != scope;
    final victims =
        await (select(localNotes)..where(
              (n) =>
                  n.accountId.equals(accountId) &
                  n.syncState.isIn(['clean', 'unreadable']) &
                  n.kind.equals('note') &
                  n.remoteId.isNotNull() &
                  n.missingSince.isNull() &
                  n.remoteId.isNotIn(remoteIds),
            ))
            .get();
    final keep = scopeChanged || (remoteIds.isEmpty && victims.isNotEmpty);
    for (final v in victims) {
      if (v.syncState == 'clean') {
        await keepCopy(
          v,
          'removed',
          reason: keep ? 'scope_changed' : 'missing_on_server',
        );
      }
    }
    final ids = victims.map((v) => v.id).toList();
    if (keep) {
      await (update(localNotes)..where((n) => n.id.isIn(ids))).write(
        LocalNotesCompanion(
          missingSince: Value(DateTime.now().millisecondsSinceEpoch),
        ),
      );
    } else {
      await (delete(localNotes)..where((n) => n.id.isIn(ids))).go();
    }
    if (scope != null) {
      await customUpdate(
        'INSERT INTO sync_statuses (account_id, scope) VALUES (?1, ?2) '
        'ON CONFLICT (account_id) DO UPDATE SET scope = excluded.scope',
        variables: [Variable.withString(accountId), Variable.withString(scope)],
        updates: {syncStatuses},
      );
    }
    return keep ? victims.length : 0;
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
      if (record is NoteIdOnly) {
        // Still listed, so no longer missing.
        await (update(localNotes)..where(
              (n) =>
                  n.accountId.equals(accountId) &
                  n.remoteId.equals(record.id) &
                  n.missingSince.isNotNull(),
            ))
            .write(const LocalNotesCompanion(missingSince: Value(null)));
        continue;
      }
      if (record is! RemoteNote && record is! UnreadableNote) continue;
      final existing =
          await (select(localNotes)..where(
                (n) =>
                    n.accountId.equals(accountId) &
                    n.remoteId.equals(record.id),
              ))
              .getSingleOrNull();
      if (record is UnreadableNote) {
        // Keep what is stored and say that it may be stale; a note never
        // seen gets a locked placeholder so it does not vanish.
        if (existing == null) {
          await into(localNotes).insert(
            LocalNotesCompanion.insert(
              id: const Uuid().v4(),
              accountId: accountId,
              remoteId: Value(record.id),
              title: '',
              content: '',
              syncState: const Value('unreadable'),
              unreadable: const Value(true),
              updatedAt: DateTime.now().millisecondsSinceEpoch,
            ),
          );
        } else if (existing.kind == 'note') {
          await (update(localNotes)..where((n) => n.id.equals(existing.id)))
              .write(const LocalNotesCompanion(unreadable: Value(true)));
        }
        continue;
      }
      if (record is! RemoteNote) continue;
      if (existing != null &&
          existing.syncState != 'clean' &&
          existing.syncState != 'unreadable') {
        continue;
      }
      final values = LocalNotesCompanion(
        unreadable: const Value(false),
        missingSince: const Value(null),
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
        // A shared file moved into the Notes folder is an ordinary note now.
        kind: const Value('note'),
        davPath: const Value(null),
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
