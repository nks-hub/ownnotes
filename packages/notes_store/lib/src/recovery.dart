import 'dart:async';
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

/// A run of lines that differs between the device and the server text:
/// lines `[deviceStart, deviceEnd)` of the device text correspond to
/// `[serverStart, serverEnd)` of the server text. Either side may be empty
/// (an insertion or a deletion).
typedef ChangedBlock = ({
  int deviceStart,
  int deviceEnd,
  int serverStart,
  int serverEnd,
});

/// The changed blocks between [device] and [server], in text order. A text
/// too large to compare line by line gives one block for all of it.
List<ChangedBlock> compareBlocks(String device, String server) {
  if (device == server) return const [];
  final a = device.split('\n'), b = server.split('\n');
  final hunks = _hunks(a, b);
  if (hunks == null) {
    return [
      (
        deviceStart: 0,
        deviceEnd: a.length,
        serverStart: 0,
        serverEnd: b.length,
      ),
    ];
  }
  var shift = 0;
  final blocks = <ChangedBlock>[];
  for (final h in hunks) {
    final start = h.start + shift;
    shift += h.lines.length - (h.end - h.start);
    blocks.add((
      deviceStart: h.start,
      deviceEnd: h.end,
      serverStart: start,
      serverEnd: start + h.lines.length,
    ));
  }
  return blocks;
}

/// What happened to a request to apply the owner's decision.
enum ConflictStatus {
  /// The note was updated; an upload follows through the ordinary queue.
  applied,

  /// The server holds another version than the one compared. Nothing was
  /// applied; compare again.
  serverChanged,

  /// The note is gone from the server.
  serverDeleted,

  /// The server no longer lets this account edit the note.
  permissionLost,
}

final class ConflictOutcome {
  const ConflictOutcome(this.status, [this.server]);
  final ConflictStatus status;

  /// The version read again, for [ConflictStatus.serverChanged] and
  /// [ConflictStatus.permissionLost].
  final RemoteNote? server;
}

/// What the owner picked as the final text.
enum ConflictChoice { result, server }

/// These transitions require an explicit user decision in the conflict UI.
final class NoteRecovery {
  NoteRecovery(this.database);
  final NotesDatabase database;

  /// Why the note waits for a decision: the code of the operation that
  /// stopped, e.g. `remote_conflict`, `remote_deleted`, `remote_readonly`,
  /// `move_integrity_required`, `write_outcome_unknown`; null when unknown.
  Future<String?> reason(LocalNote note) async {
    final rows =
        await (database.select(database.operations)
              ..where(
                (o) =>
                    o.noteId.equals(note.id) & o.state.equals('needsDecision'),
              )
              ..orderBy([(o) => OrderingTerm.desc(o.revision)])
              ..limit(1))
            .get();
    return rows.isEmpty ? null : rows.single.errorCode;
  }

  /// Keeps the device text and the server text compared as recovery copies.
  /// They stay until [discardCopy].
  Future<void> retainOriginals(LocalNote device, RemoteNote server) =>
      database.transaction(() async {
        await database.keepCopy(device, 'device', reason: 'compared');
        await database.keepCopy(
          device,
          'server',
          reason: 'compared',
          title: server.title,
          content: server.content,
          category: server.category,
          favorite: server.favorite,
          etag: server.etag,
        );
      });

  /// Applies the owner's decision after checking the server again.
  ///
  /// Both originals are stored first. [readServer] reads the note now (null
  /// when it is gone); when its ETag is not [inspected]'s, nothing is applied
  /// so the comparison can be shown again. [content], [title] and
  /// [category] describe the Result for [ConflictChoice.result]. A network
  /// error from [readServer] propagates and applies nothing.
  Future<ConflictOutcome> resolve({
    required LocalNote expected,
    required RemoteNote inspected,
    required Future<RemoteNote?> Function() readServer,
    required ConflictChoice choice,
    String? content,
    String? title,
    String? category,
  }) async {
    await retainOriginals(expected, inspected);
    final fresh = await readServer();
    if (fresh == null) {
      return const ConflictOutcome(ConflictStatus.serverDeleted);
    }
    if (fresh.etag != inspected.etag) {
      await database.keepCopy(
        expected,
        'server',
        reason: 'compared',
        title: fresh.title,
        content: fresh.content,
        category: fresh.category,
        favorite: fresh.favorite,
        etag: fresh.etag,
      );
      return ConflictOutcome(ConflictStatus.serverChanged, fresh);
    }
    final keepLocal = choice == ConflictChoice.result;
    if (keepLocal && fresh.readonly) {
      return ConflictOutcome(ConflictStatus.permissionLost, fresh);
    }
    await useRemote(
      expected: expected,
      remote: fresh,
      keepLocal: keepLocal,
      content: keepLocal ? content : null,
      title: keepLocal ? title : null,
      category: keepLocal ? category : null,
    );
    await _forgetResult(expected.id);
    return const ConflictOutcome(ConflictStatus.applied);
  }

  /// Remembers an unfinished Result so leaving the comparison loses nothing.
  Future<void> saveResult(LocalNote note, String text) =>
      database.transaction(() async {
        await _forgetResult(note.id);
        if (text != note.content) {
          await database.keepCopy(note, 'result', content: text);
        }
      });

  /// The unfinished Result stored by [saveResult], if any.
  Future<String?> savedResult(LocalNote note) async {
    final rows = await (database.select(
      database.recoveryCopies,
    )..where((c) => c.noteId.equals(note.id) & c.kind.equals('result'))).get();
    return rows.isEmpty ? null : rows.first.content;
  }

  Future<void> _forgetResult(String noteId) => (database.delete(
    database.recoveryCopies,
  )..where((c) => c.noteId.equals(noteId) & c.kind.equals('result'))).go();

  /// Recovery copies of an account, newest first. Results in progress are
  /// not listed.
  Stream<List<RecoveryCopy>> watchCopies(String accountId) =>
      (database.select(database.recoveryCopies)
            ..where(
              (c) =>
                  c.accountId.equals(accountId) & c.kind.equals('result').not(),
            )
            ..orderBy([(c) => OrderingTerm.desc(c.createdAt)]))
          .watch();

  /// Removes a copy for good. Only the owner does this.
  Future<void> discardCopy(String accountId, String copyId) => (database.delete(
    database.recoveryCopies,
  )..where((c) => c.id.equals(copyId) & c.accountId.equals(accountId))).go();

  /// A new local note with the text of a copy; the copy stays.
  Future<String> restoreCopy(String accountId, String copyId) async {
    final copy =
        await (database.select(database.recoveryCopies)..where(
              (c) => c.id.equals(copyId) & c.accountId.equals(accountId),
            ))
            .getSingleOrNull();
    if (copy == null) throw StateError('copy_missing');
    return database.createDraft(
      accountId,
      title: copy.title,
      content: copy.content,
      category: copy.category,
    );
  }

  /// A note the server stopped listing although its scope may have changed:
  /// make it an ordinary new note, to be uploaded again.
  Future<void> keepMissingAsNew(LocalNote expected) =>
      database.transaction(() async {
        final current = await database.note(expected.accountId, expected.id);
        if (current == null || current.missingSince == null) {
          throw StateError('decision_stale');
        }
        await (database.update(
          database.localNotes,
        )..where((n) => n.id.equals(current.id))).write(
          LocalNotesCompanion(
            remoteId: const Value(null),
            etag: const Value(null),
            baseContent: const Value(null),
            baseTitle: const Value(null),
            baseCategory: const Value(null),
            baseFavorite: const Value(null),
            missingSince: const Value(null),
            syncState: const Value('draft'),
            revision: Value(current.revision + 1),
          ),
        );
        await _bumpEpoch(current.accountId);
      });

  /// Drops a missing note from this phone; its recovery copy stays.
  Future<void> removeMissing(LocalNote expected) =>
      database.transaction(() async {
        final current = await database.note(expected.accountId, expected.id);
        if (current == null || current.missingSince == null) return;
        await database.keepCopy(current, 'removed', reason: 'owner_removed');
        await (database.delete(
          database.localNotes,
        )..where((n) => n.id.equals(current.id))).go();
        await _bumpEpoch(current.accountId);
      });

  Future<void> _bumpEpoch(String accountId) async {
    final account = await database.account(accountId);
    if (account == null) throw StateError('account_missing');
    await (database.update(
      database.accounts,
    )..where((a) => a.id.equals(account.id))).write(
      AccountsCompanion(mutationEpoch: Value(account.mutationEpoch + 1)),
    );
  }

  /// [content] replaces the local text, e.g. with [mergeVersions]; it is
  /// uploaded like kept local changes, together with [title] and [category]
  /// when given.
  Future<void> useRemote({
    required LocalNote expected,
    required RemoteNote remote,
    required bool keepLocal,
    String? content,
    String? title,
    String? category,
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
        title: Value(keepLocal ? title ?? current.title : remote.title),
        content: Value(keepLocal ? content ?? current.content : remote.content),
        category: Value(
          keepLocal ? category ?? current.category : remote.category,
        ),
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
  ///
  /// [content] is the text of the new note when it is not the device text,
  /// e.g. an edited Result; the device text stays in the archived row.
  Future<String> copyAsNew(LocalNote expected, {String? content}) =>
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
                content: content ?? current.content,
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
    await _bumpEpoch(note.accountId);
  }
}

/// Why something needs the owner, most urgent first.
enum AttentionKind {
  /// The phone could not keep the owner's text.
  saveFailure,

  /// Device and server differ; [AttentionItem.reason] says why.
  decision,

  /// The server refused or could not be asked; [AttentionItem.reason] is the
  /// problem category. The note can be restored with [NotesDatabase.undoDelete].
  failedDeletion,

  /// The server stopped listing the note; it is kept here.
  missing,

  /// The server cannot hand out the text; the copy here may be stale.
  unreadable,

  /// A deletion waiting for the next sync; Undo is still possible.
  pendingDeletion,
}

final class AttentionItem {
  const AttentionItem({
    required this.kind,
    required this.accountId,
    this.note,
    this.noteId,
    this.reason,
  });
  final AttentionKind kind;
  final String accountId;

  /// The row; null for a save failure whose note is not stored.
  final LocalNote? note;
  final String? noteId;
  final String? reason;
}

/// The "Needs attention" list of an account: decisions, deletions waiting or
/// failed, unreadable and missing notes (from the database, so it survives a
/// restart) and local save failures (reported by the editor, in memory,
/// because the database itself refused the write).
final class AttentionFeed {
  AttentionFeed(this.database);
  final NotesDatabase database;
  final Map<String, Map<String, String?>> _failures = {};
  final _changes = StreamController<void>.broadcast(sync: true);

  /// The editor could not persist [noteId]; [reason] is a short code.
  void reportSaveFailure(String accountId, String noteId, [String? reason]) {
    (_failures[accountId] ??= {})[noteId] = reason;
    _changes.add(null);
  }

  void clearSaveFailure(String accountId, String noteId) {
    _failures[accountId]?.remove(noteId);
    _changes.add(null);
  }

  Stream<List<AttentionItem>> watch(String accountId) {
    late final StreamController<List<AttentionItem>> out;
    StreamSubscription<List<LocalNote>>? rows;
    StreamSubscription<void>? changes;
    var latest = <LocalNote>[];
    var ready = false;
    var token = 0;
    Future<void> emit() async {
      if (!ready) return;
      final mine = ++token;
      final items = await _items(accountId, latest);
      if (mine == token && !out.isClosed) out.add(items);
    }

    out = StreamController<List<AttentionItem>>(
      onListen: () {
        rows =
            (database.select(database.localNotes)..where(
                  (n) =>
                      n.accountId.equals(accountId) &
                      (n.syncState.isIn([
                            'needsDecision',
                            'deleting',
                            'unreadable',
                          ]) |
                          n.unreadable.equals(true) |
                          n.missingSince.isNotNull()),
                ))
                .watch()
                .listen((r) {
                  latest = r;
                  ready = true;
                  emit();
                }, onError: out.addError);
        changes = _changes.stream.listen((_) => emit());
      },
      onCancel: () async {
        await rows?.cancel();
        await changes?.cancel();
      },
    );
    return out.stream;
  }

  Future<List<AttentionItem>> _items(
    String accountId,
    List<LocalNote> rows,
  ) async {
    final decisions = rows.where((n) => n.syncState == 'needsDecision');
    final reasons = <String, String?>{};
    if (decisions.isNotEmpty) {
      final ops =
          await (database.select(database.operations)
                ..where(
                  (o) =>
                      o.noteId.isIn(decisions.map((n) => n.id)) &
                      o.state.equals('needsDecision'),
                )
                ..orderBy([(o) => OrderingTerm.asc(o.revision)]))
              .get();
      for (final o in ops) {
        reasons[o.noteId] = o.errorCode;
      }
    }
    final items = <AttentionItem>[
      for (final e
          in (_failures[accountId] ?? const <String, String?>{}).entries)
        AttentionItem(
          kind: AttentionKind.saveFailure,
          accountId: accountId,
          noteId: e.key,
          reason: e.value,
        ),
      for (final n in rows)
        if (n.syncState == 'needsDecision')
          AttentionItem(
            kind: AttentionKind.decision,
            accountId: accountId,
            note: n,
            noteId: n.id,
            reason: reasons[n.id],
          )
        else if (n.syncState == 'deleting')
          AttentionItem(
            kind: n.deleteError == null
                ? AttentionKind.pendingDeletion
                : AttentionKind.failedDeletion,
            accountId: accountId,
            note: n,
            noteId: n.id,
            reason: n.deleteError,
          )
        else if (n.missingSince != null)
          AttentionItem(
            kind: AttentionKind.missing,
            accountId: accountId,
            note: n,
            noteId: n.id,
          )
        else if (n.unreadable == true || n.syncState == 'unreadable')
          AttentionItem(
            kind: AttentionKind.unreadable,
            accountId: accountId,
            note: n,
            noteId: n.id,
          ),
    ];
    items.sort((a, b) => a.kind.index.compareTo(b.kind.index));
    return items;
  }
}
