import 'package:drift/drift.dart';
import 'package:notes_protocol/notes_protocol.dart';
import 'package:uuid/uuid.dart';
import 'database.dart';

/// These transitions require an explicit user decision in the conflict UI.
final class NoteRecovery {
  NoteRecovery(this.database);
  final NotesDatabase database;

  Future<void> useRemote({
    required LocalNote expected,
    required RemoteNote remote,
    required bool keepLocal,
  }) => database.transaction(() async {
    final current = await _current(expected);
    if (current.remoteId != remote.id) {
      throw StateError('remote_identity_changed');
    }
    if (keepLocal && remote.readonly) throw StateError('remote_readonly');
    await (database.update(
      database.localNotes,
    )..where((n) => n.id.equals(current.id))).write(
      LocalNotesCompanion(
        title: Value(keepLocal ? current.title : remote.title),
        content: Value(keepLocal ? current.content : remote.content),
        category: Value(keepLocal ? current.category : remote.category),
        favorite: Value(keepLocal ? current.favorite : remote.favorite),
        baseTitle: Value(remote.title),
        baseContent: Value(remote.content),
        baseCategory: Value(remote.category),
        baseFavorite: Value(remote.favorite),
        etag: Value(remote.etag),
        readonly: Value(remote.readonly),
        revision: Value(current.revision + 1),
        syncState: Value(keepLocal ? 'draft' : 'clean'),
      ),
    );
    await _dismiss(current);
  });

  /// Preserve the uncertain operation and original row for audit/recovery.
  /// The user is warned that the server may already contain another copy.
  Future<String> copyAsNew(LocalNote expected) =>
      database.transaction(() async {
        final current = await _current(expected);
        final id = const Uuid().v4();
        await database
            .into(database.localNotes)
            .insert(
              LocalNotesCompanion.insert(
                id: id,
                accountId: current.accountId,
                title: current.title,
                content: current.content,
                category: Value(current.category),
                favorite: Value(current.favorite),
                updatedAt: DateTime.now().millisecondsSinceEpoch,
              ),
            );
        await (database.update(
          database.localNotes,
        )..where((n) => n.id.equals(current.id))).write(
          const LocalNotesCompanion(syncState: Value('recoveryArchived')),
        );
        await _dismiss(current);
        return id;
      });

  Future<LocalNote> _current(LocalNote expected) async {
    final current = await database.note(expected.accountId, expected.id);
    if (current == null ||
        current.revision != expected.revision ||
        current.syncState != 'needsDecision') {
      throw StateError('decision_stale');
    }
    return current;
  }

  Future<void> _dismiss(LocalNote note) async {
    await (database.update(database.operations)..where(
          (o) => o.noteId.equals(note.id) & o.state.equals('needsDecision'),
        ))
        .write(const OperationsCompanion(state: Value('dismissed')));
    final account = await database.account(note.accountId);
    if (account == null) throw StateError('account_missing');
    await (database.update(
      database.accounts,
    )..where((a) => a.id.equals(account.id))).write(
      AccountsCompanion(mutationEpoch: Value(account.mutationEpoch + 1)),
    );
  }
}
