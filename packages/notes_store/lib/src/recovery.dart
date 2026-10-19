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

/// Applies the changes both sides made to [base] together, line by line.
/// Lines both sides inserted at the same place are all kept, local first.
/// Returns null when both changed the same lines differently, or the texts
/// are too large to compare on a phone.
String? mergeThreeWay(String base, String local, String remote) {
  if (local == remote || remote == base) return local;
  if (local == base) return remote;
  final o = base.split('\n');
  final a = _hunks(o, local.split('\n'));
  final b = _hunks(o, remote.split('\n'));
  if (a == null || b == null) return null;
  final out = <String>[];
  var pos = 0, i = 0, j = 0;
  while (i < a.length || j < b.length) {
    // The next hunk by position; at a tie an insertion first, then local.
    final takeA =
        j == b.length ||
        (i < a.length &&
            (a[i].start < b[j].start ||
                a[i].start == b[j].start && a[i].end <= b[j].end));
    final h = takeA ? a[i++] : b[j++];
    final others = takeA ? b : a;
    final k = takeA ? j : i;
    if (k < others.length) {
      final other = others[k];
      final same =
          other.start == h.start &&
          other.end == h.end &&
          other.lines.join('\n') == h.lines.join('\n');
      if (same) {
        takeA ? j++ : i++;
      } else if (other.start < h.end && h.start < other.end) {
        return null;
      }
    }
    out
      ..addAll(o.sublist(pos, h.start))
      ..addAll(h.lines);
    pos = h.end;
  }
  out.addAll(o.sublist(pos));
  return out.join('\n');
}

typedef _Hunk = ({int start, int end, List<String> lines});

/// Ranges of [o] that [x] replaces, in order, from a longest common line
/// sequence. Null when too large.
List<_Hunk>? _hunks(List<String> o, List<String> x) {
  var start = 0;
  while (start < o.length && start < x.length && o[start] == x[start]) {
    start++;
  }
  var end = 0;
  while (end < o.length - start &&
      end < x.length - start &&
      o[o.length - 1 - end] == x[x.length - 1 - end]) {
    end++;
  }
  final n = o.length - end, m = x.length - end;
  if ((n - start) * (m - start) > 4000000) return null;
  final common = List.generate(
    n - start + 1,
    (_) => List.filled(m - start + 1, 0),
  );
  for (var i = n - 1; i >= start; i--) {
    for (var j = m - 1; j >= start; j--) {
      common[i - start][j - start] = o[i] == x[j]
          ? common[i - start + 1][j - start + 1] + 1
          : max(
              common[i - start + 1][j - start],
              common[i - start][j - start + 1],
            );
    }
  }
  final hunks = <_Hunk>[];
  int? from;
  final lines = <String>[];
  var i = start, j = start;
  void flush() {
    if (from == null) return;
    hunks.add((start: from!, end: i, lines: [...lines]));
    from = null;
    lines.clear();
  }

  while (i < n || j < m) {
    if (i < n && j < m && o[i] == x[j]) {
      flush();
      i++;
      j++;
    } else if (j == m ||
        (i < n &&
            common[i - start + 1][j - start] >=
                common[i - start][j - start + 1])) {
      from ??= i;
      i++;
    } else {
      from ??= i;
      lines.add(x[j++]);
    }
  }
  flush();
  return hunks;
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
