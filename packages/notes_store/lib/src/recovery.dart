import 'dart:math';
import 'package:drift/drift.dart';
import 'package:notes_protocol/notes_protocol.dart';
import 'package:uuid/uuid.dart';
import 'database.dart';

/// Both versions of a note in one text, line by line: lines both have appear
/// once and in place, where they differ the local lines come first, then the
/// server's. Two phones adding to one list keep both. A line changed on one
/// phone appears in both forms; the conflict screen shows the result before
/// it is saved.
String mergeVersions(String local, String remote) {
  final a = local.split('\n'), b = remote.split('\n');
  var start = 0;
  while (start < a.length && start < b.length && a[start] == b[start]) {
    start++;
  }
  var end = 0;
  while (end < a.length - start &&
      end < b.length - start &&
      a[a.length - 1 - end] == b[b.length - 1 - end]) {
    end++;
  }
  final x = a.sublist(start, a.length - end);
  final y = b.sublist(start, b.length - end);
  final middle = <String>[];
  if (x.length * y.length > 4000000) {
    // Too large to compare line by line on a phone; keep everything.
    middle.addAll([...x, ...y]);
  } else {
    // common[i][j]: length of the longest common line sequence of x[i..], y[j..].
    final common = List.generate(
      x.length + 1,
      (_) => List.filled(y.length + 1, 0),
    );
    for (var i = x.length - 1; i >= 0; i--) {
      for (var j = y.length - 1; j >= 0; j--) {
        common[i][j] = x[i] == y[j]
            ? common[i + 1][j + 1] + 1
            : max(common[i + 1][j], common[i][j + 1]);
      }
    }
    var i = 0, j = 0;
    while (i < x.length || j < y.length) {
      if (i < x.length && j < y.length && x[i] == y[j]) {
        middle.add(x[i]);
        i++;
        j++;
      } else if (j == y.length ||
          (i < x.length && common[i + 1][j] >= common[i][j + 1])) {
        middle.add(x[i++]);
      } else {
        middle.add(y[j++]);
      }
    }
  }
  return [...a.take(start), ...middle, ...a.skip(a.length - end)].join('\n');
}

/// These transitions require an explicit user decision in the conflict UI.
final class NoteRecovery {
  NoteRecovery(this.database);
  final NotesDatabase database;

  /// [content] replaces the local text, e.g. with [mergeVersions]; it is
  /// uploaded like kept local changes.
  Future<void> useRemote({
    required LocalNote expected,
    required RemoteNote remote,
    required bool keepLocal,
    String? content,
  }) => database.transaction(() async {
    assert(content == null || keepLocal);
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
        content: Value(keepLocal ? content ?? current.content : remote.content),
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
          // The archive gives up the server note, so the next pull brings
          // the server version back as an ordinary note.
          const LocalNotesCompanion(
            remoteId: Value(null),
            etag: Value(null),
            syncState: Value('recoveryArchived'),
          ),
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
