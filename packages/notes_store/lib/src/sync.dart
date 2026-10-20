import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:notes_protocol/notes_protocol.dart';
import 'package:uuid/uuid.dart';
import 'database.dart';
import 'recovery.dart';

/// One coordinator per process (the app, a background worker). They share
/// the database and take turns through a per-account lease, renewed before
/// every request; the client timeout is far shorter than [lease].
/// A persisted sending operation is never replayed automatically after a crash.
final class SyncCoordinator {
  SyncCoordinator(
    this.database,
    this.clientFor, {
    this.lease = const Duration(minutes: 2),
    this.sharingFor,
    this.shareListInterval = const Duration(seconds: 60),
  });

  /// When set, notes shared with the account are synced over WebDAV as well.
  final Future<SharingClient> Function(Account account)? sharingFor;

  /// How often the list of incoming shares is read; the open note's ETag is
  /// checked on every pass, so live edits do not wait for this.
  final Duration shareListInterval;
  final Map<String, DateTime> _sharesListed = {};
  final NotesDatabase database;
  final Duration lease;
  final String _owner = const Uuid().v4();
  final Future<NotesClient> Function(Account account) clientFor;
  final Map<String, Future<void>> _running = {};
  final Map<String, String> _problems = {};

  /// Why the last sync of [accountId] left notes unsent: `offline`, `auth`,
  /// `locked`, `storage_full` or `server`; null when nothing went wrong.
  String? problem(String accountId) => _problems[accountId];

  /// [relist] reads the incoming shares now, e.g. right after accepting one.
  Future<void> sync(String accountId, {bool relist = false}) {
    if (relist) _sharesListed.remove(accountId);
    final existing = _running[accountId];
    if (existing != null) return existing;
    final result = _sync(accountId);
    _running[accountId] = result;
    return result.whenComplete(() => _running.remove(accountId));
  }

  /// Call once during startup. An account whose lease another process holds
  /// is skipped: its worker is still sending, nothing was interrupted.
  Future<void> recoverInterruptedWrites() async {
    for (final account in await database.select(database.accounts).get()) {
      if (!await database.holdLease(account.id, _owner, lease)) continue;
      try {
        await _recover(account.id);
      } finally {
        await database.releaseLease(account.id, _owner);
      }
    }
  }

  /// With the lease held, a sending operation belongs to a worker that died
  /// or lost its lease; a late receipt from it no longer matches 'sending'.
  Future<void> _recover(String accountId) => database.transaction(() async {
    final interrupted =
        await (database.select(database.operations)..where(
              (o) => o.accountId.equals(accountId) & o.state.equals('sending'),
            ))
            .get();
    for (final operation in interrupted) {
      await _decision(operation, 'interrupted_write');
    }
  });

  Future<void> _sync(String accountId) async {
    _problems.remove(accountId);
    // Another process is syncing this account; its results land in the
    // shared database.
    if (!await database.holdLease(accountId, _owner, lease)) return;
    try {
      await _recover(accountId);
      await _pass(accountId);
    } catch (e) {
      _problems[accountId] = _reason(e);
      rethrow;
    } finally {
      await database.releaseLease(accountId, _owner);
    }
  }

  Future<void> _keepLease(String accountId) async {
    if (!await database.holdLease(accountId, _owner, lease)) {
      throw StateError('sync_lease_lost');
    }
  }

  static String _reason(Object error) => switch (error) {
    NotesTransportException() || MutationUncertain() => 'offline',
    NotesHttpException(statusCode: 401) => 'auth',
    NotesHttpException(statusCode: 423) => 'locked',
    NotesHttpException(statusCode: 507) => 'storage_full',
    _ => 'server',
  };

  Future<void> _pass(String accountId) async {
    final account = await database.account(accountId);
    if (account == null) return;
    final client = await clientFor(account);
    final drafts =
        await (database.select(database.localNotes)..where(
              (n) =>
                  n.accountId.equals(accountId) &
                  n.kind.equals('note') &
                  n.syncState.equals('draft'),
            ))
            .get();
    final deletions =
        await (database.select(database.localNotes)..where(
              (n) =>
                  n.accountId.equals(accountId) &
                  n.kind.equals('note') &
                  n.syncState.equals('deleting'),
            ))
            .get();
    // A write that fails in transport cannot prove it was not applied and
    // becomes a decision. Send only right after the server answered, so an
    // offline edit stays a plain draft (and this throws to report offline).
    if (drafts.isNotEmpty || deletions.isNotEmpty) {
      await client.list(chunkSize: 1);
    }
    for (final draft in drafts) {
      if (await database.account(accountId) == null) return;
      await _keepLease(accountId);
      await _push(client, draft);
    }
    for (final note in deletions) {
      if (await database.account(accountId) == null) return;
      await _keepLease(accountId);
      await _delete(client, note);
    }
    if (await database.account(accountId) == null) return;
    if (!await _pull(client, accountId, _watermarks[accountId])) {
      _watermarks.remove(accountId);
      await _pull(client, accountId, null);
    }
    await _shared(account);
  }

  // shortcut: kept in memory, so the first sync after start is a full pull;
  // persist it per account if full pulls of large accounts become slow.
  final Map<String, int> _watermarks = {};

  /// With [pruneBefore] the server sends notes unchanged since then as id
  /// only. Returns false when such an id has no local row, so the caller
  /// repeats the pull in full instead of missing that note.
  Future<bool> _pull(
    NotesClient client,
    String accountId,
    int? pruneBefore,
  ) async {
    final epoch = await database.readEpoch(accountId);
    String? cursor;
    DateTime? watermark;
    final seenCursors = <String>{};
    final listed = <int>{};
    final sent = <int>{};
    do {
      await _keepLease(accountId);
      final page = await client.list(cursor: cursor, pruneBefore: pruneBefore);
      // The first chunk's Last-Modified is when the whole listing started.
      if (cursor == null) watermark = page.lastModified;
      if (!await database.applyPull(accountId, epoch, page.notes)) return true;
      listed.addAll(page.notes.map((n) => n.id));
      sent.addAll(page.notes.where((n) => n is! NoteIdOnly).map((n) => n.id));
      cursor = page.cursor;
      if (cursor != null && !seenCursors.add(cursor)) {
        throw const NotesProtocolException('repeated_chunk_cursor');
      }
    } while (cursor != null);
    // The last chunk repeats notes of earlier chunks as id only, too.
    final pruned = listed.difference(sent);
    if (pruneBefore != null && pruned.isNotEmpty) {
      final known =
          await (database.select(database.localNotes)..where(
                (n) => n.accountId.equals(accountId) & n.remoteId.isIn(pruned),
              ))
              .get();
      if (known.length != pruned.length) return false;
    }
    await database.census(accountId, epoch, listed);
    if (watermark != null) {
      _watermarks[accountId] = watermark.millisecondsSinceEpoch ~/ 1000;
    }
    return true;
  }

  /// DELETE has no If-Match on the server, so the note is read first: a
  /// version changed elsewhere is restored instead of being thrown away.
  /// Retrying is safe; a note already gone answers 404.
  Future<void> _delete(NotesClient client, LocalNote note) async {
    final remoteId = note.remoteId!;
    final etag = note.etag;
    Future<void> forget() =>
        (database.delete(database.localNotes)..where(
              (n) => n.id.equals(note.id) & n.syncState.equals('deleting'),
            ))
            .go();
    try {
      final read = await client.get(remoteId, ifNoneMatch: etag);
      if (read is RemoteNote && read.etag != etag) {
        await (database.update(database.localNotes)..where(
              (n) => n.id.equals(note.id) & n.syncState.equals('deleting'),
            ))
            .write(
              LocalNotesCompanion(
                title: Value(read.title),
                content: Value(read.content),
                category: Value(read.category),
                favorite: Value(read.favorite),
                readonly: Value(read.readonly),
                etag: Value(read.etag),
                baseTitle: Value(read.title),
                baseContent: Value(read.content),
                baseCategory: Value(read.category),
                baseFavorite: Value(read.favorite),
                syncState: const Value('clean'),
              ),
            );
        return;
      }
      await client.delete(remoteId);
      await forget();
    } on NotesHttpException catch (e) {
      if (e.statusCode == 404) await forget();
    } on MutationUncertain {
      // Stays "deleting"; the next sync reads it again.
    }
  }

  Future<void> _push(
    NotesClient client,
    LocalNote selected, {
    bool retry = true,
  }) async {
    final operation = await database.transaction(() async {
      final current = await database.note(selected.accountId, selected.id);
      if (current == null || current.syncState != 'draft') return null;
      final open =
          await (database.select(database.operations)..where(
                (o) =>
                    o.noteId.equals(current.id) &
                    o.state.isNotIn(['done', 'dismissed']),
              ))
              .get();
      if (open.isNotEmpty) return null;
      // An empty title on a stored note means "keep the server's file name"
      // (e.g. an editor opened before the CREATE receipt named the note).
      // A new one is named from its first line, as the Notes web app does.
      final title = current.title.trim().isNotEmpty
          ? current.title
          : current.remoteId != null
          ? current.baseTitle ?? ''
          : titleFromContent(current.content);
      final fields = <String, Object>{
        if (current.remoteId == null || title != current.baseTitle)
          'title': title,
        if (current.remoteId == null || current.content != current.baseContent)
          'content': current.content,
        if (current.remoteId == null ||
            current.category != current.baseCategory)
          'category': current.category,
        if (current.remoteId == null ||
            current.favorite != current.baseFavorite)
          'favorite': current.favorite,
      };
      // A read-only note may only send its favorite star.
      if (current.readonly && fields.keys.any((k) => k != 'favorite')) {
        return null;
      }
      if (fields.isEmpty) {
        await (database.update(database.localNotes)
              ..where((n) => n.id.equals(current.id)))
            .write(const LocalNotesCompanion(syncState: Value('clean')));
        return null;
      }
      final id = const Uuid().v4();
      final payload = jsonEncode({
        'remoteId': current.remoteId,
        'etag': current.etag,
        'title': title,
        'content': current.content,
        'category': current.category,
        'favorite': current.favorite,
        'fields': fields,
      });
      await database
          .into(database.operations)
          .insert(
            OperationsCompanion.insert(
              id: id,
              accountId: current.accountId,
              noteId: current.id,
              revision: current.revision,
              kind: current.remoteId == null ? 'create' : 'update',
              payload: payload,
              state: const Value('sending'),
            ),
          );
      await (database.update(database.localNotes)
            ..where((n) => n.id.equals(current.id)))
          .write(const LocalNotesCompanion(syncState: Value('sending')));
      return (database.select(
        database.operations,
      )..where((o) => o.id.equals(id))).getSingle();
    });
    if (operation == null) return;
    final intent = jsonDecode(operation.payload) as Map<String, Object?>;
    final fields = intent['fields']! as Map<String, Object?>;
    try {
      final NoteRecord result;
      if (operation.kind == 'create') {
        result = await client.create(
          title: intent['title']! as String,
          content: intent['content']! as String,
          category: intent['category']! as String,
          favorite: intent['favorite']! as bool,
        );
      } else {
        final etag = intent['etag'];
        if (etag is! String) {
          await _decision(operation, 'missing_etag');
          return;
        }
        // A category change moves the note file to another folder. The
        // server moves `.attachments.<id>` along only when the target has no
        // such folder, and a note response cannot confirm it, so notes that
        // reference attachments wait for a decision. A rename stays in the
        // same folder next to its attachments.
        if (fields.containsKey('category') &&
            (intent['content']! as String).contains('.attachments.')) {
          await _decision(operation, 'move_integrity_required');
          return;
        }
        result = await client.update(
          intent['remoteId']! as int,
          etag: etag,
          patch: NotePatch(
            content: fields['content'] as String?,
            title: fields['title'] as String?,
            category: fields['category'] as String?,
            favorite: fields['favorite'] as bool?,
          ),
        );
      }
      await _receipt(operation, result, intent);
    } on NoteConflict catch (e) {
      // The server answers 412 with the note it holds now.
      if (await _rebase(operation, e.remote)) {
        if (retry) await _push(client, selected, retry: false);
        return;
      }
      await _decision(operation, 'remote_conflict');
    } catch (e) {
      // Even an HTTP error can follow a partially applied mutation.
      if (operation.kind == 'update' &&
          await _reread(client, operation, intent, e)) {
        return;
      }
      await _decision(operation, 'write_outcome_unknown');
    }
  }

  /// Another device (or account) changed the note since this one read it.
  /// When the two edits touch different lines, they are combined onto the
  /// server version and queued again; the same lines changed differently
  /// still wait for a decision.
  Future<bool> _rebase(Operation operation, NoteRecord remote) async {
    if (remote is! RemoteNote || remote.readonly) return false;
    final read = remote;
    return database.transaction(() async {
      final live = await (database.select(
        database.operations,
      )..where((o) => o.id.equals(operation.id))).getSingleOrNull();
      final current = await database.note(
        operation.accountId,
        operation.noteId,
      );
      if (live?.state != 'sending' ||
          current == null ||
          current.remoteId != read.id) {
        return false;
      }
      String? pick(String? base, String local, String remote) =>
          local == remote || remote == base
          ? local
          : local == base
          ? remote
          : null;
      // An empty title keeps the server's file name.
      final title = pick(
        current.baseTitle,
        current.title.trim().isEmpty ? current.baseTitle ?? '' : current.title,
        read.title,
      );
      final category = pick(
        current.baseCategory,
        current.category,
        read.category,
      );
      final content = mergeThreeWay(
        current.baseContent ?? '',
        current.content,
        read.content,
      );
      if (title == null || category == null || content == null) return false;
      await (database.update(
        database.operations,
      )..where((o) => o.id.equals(operation.id))).write(
        const OperationsCompanion(
          state: Value('dismissed'),
          errorCode: Value('merged'),
        ),
      );
      await (database.update(
        database.localNotes,
      )..where((n) => n.id.equals(current.id))).write(
        LocalNotesCompanion(
          title: Value(title),
          content: Value(content),
          category: Value(category),
          favorite: Value(
            current.favorite == current.baseFavorite
                ? read.favorite
                : current.favorite,
          ),
          etag: Value(read.etag),
          baseTitle: Value(read.title),
          baseContent: Value(read.content),
          baseCategory: Value(read.category),
          baseFavorite: Value(read.favorite),
          revision: Value(current.revision + 1),
          syncState: const Value('draft'),
        ),
      );
      return true;
    });
  }

  /// After a failed update a fresh read shows what the server holds. The old
  /// version means nothing was written (a locked file, full storage): the
  /// note goes back to the queue. Any later write still carries If-Match,
  /// so a late copy of this request can only end as a conflict.
  Future<bool> _reread(
    NotesClient client,
    Operation operation,
    Map<String, Object?> intent,
    Object error,
  ) async {
    final NoteReadResult read;
    try {
      read = await client.get(intent['remoteId']! as int);
    } on NotesHttpException catch (e) {
      // Deleted on another device meanwhile; the local text stays.
      if (e.statusCode != 404) return false;
      await _decision(operation, 'remote_deleted');
      return true;
    } catch (_) {
      return false;
    }
    if (read is! RemoteNote) return false;
    if (read.etag != intent['etag']) {
      await _receipt(operation, read, intent);
      return true;
    }
    if (read.readonly) {
      await _decision(operation, 'remote_readonly');
      return true;
    }
    await _requeue(operation, _reason(error));
    return true;
  }

  /// The write did not happen: the note goes back to the queue.
  Future<void> _requeue(Operation operation, String reason) async {
    _problems[operation.accountId] = reason;
    await database.transaction(() async {
      await (database.update(database.operations)..where(
            (o) => o.id.equals(operation.id) & o.state.equals('sending'),
          ))
          .write(
            OperationsCompanion(
              state: const Value('dismissed'),
              errorCode: Value('not_applied_$reason'),
            ),
          );
      await (database.update(database.localNotes)..where(
            (n) =>
                n.id.equals(operation.noteId) & n.syncState.equals('sending'),
          ))
          .write(const LocalNotesCompanion(syncState: Value('draft')));
    });
  }

  // --- Notes shared with this account, synced over WebDAV ---

  static final RegExp _noteFile = RegExp(r'\.(md|txt)$', caseSensitive: false);

  /// The note as the file holds it now; for the conflict screen.
  Future<RemoteNote> readShared(LocalNote note) async {
    final account = await database.account(note.accountId);
    final factory = sharingFor;
    if (account == null || factory == null || note.kind != 'shared') {
      throw StateError('not_shared');
    }
    return _sharedRemote(
      note,
      await (await factory(account)).read(note.davPath!),
    );
  }

  RemoteNote _sharedRemote(LocalNote row, SharedFile file) => RemoteNote(
    id: row.remoteId!,
    etag: file.etag,
    title: row.baseTitle ?? row.title,
    content: file.content,
    category: '',
    favorite: false,
    readonly: row.readonly,
    modified: DateTime.now().millisecondsSinceEpoch ~/ 1000,
  );

  Future<void> _shared(Account account) async {
    final factory = sharingFor;
    if (factory == null) return;
    final sharing = await factory(account);
    final listed = _sharesListed[account.id];
    if (listed == null ||
        DateTime.now().difference(listed) >= shareListInterval) {
      await _listShares(sharing, account.id);
      _sharesListed[account.id] = DateTime.now();
    }
    final rows =
        await (database.select(database.localNotes)..where(
              (n) =>
                  n.accountId.equals(account.id) &
                  n.kind.equals('shared') &
                  n.syncState.isIn(['draft', 'clean']),
            ))
            .get();
    for (final row in rows) {
      if (await database.account(account.id) == null) return;
      await _keepLease(account.id);
      try {
        var current = row;
        if (row.syncState == 'draft') {
          await _pushShared(sharing, row);
          final again = await database.note(account.id, row.id);
          if (again == null) continue;
          current = again;
        }
        if (current.syncState == 'clean') await _pullShared(sharing, current);
      } on NotesHttpException catch (e) {
        // Unshared or deleted by the owner; the share listing decides.
        if (e.statusCode != 404) rethrow;
      }
    }
  }

  /// New incoming shares become rows; rows whose share ended (or whose file
  /// the Notes API lists now) go when they hold no local edits.
  Future<void> _listShares(SharingClient sharing, String accountId) async {
    final incoming = [
      for (final s in await sharing.sharedWithMe())
        if (_noteFile.hasMatch(s.path)) s,
    ];
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
    for (final share in incoming) {
      if (viaNotes.contains(share.fileId)) continue;
      wanted.add(share.fileId);
      final row = byFile[share.fileId];
      if (row != null) {
        await (database.update(
          database.localNotes,
        )..where((n) => n.id.equals(row.id))).write(
          LocalNotesCompanion(
            davPath: Value(share.path),
            readonly: Value(!share.canEdit),
          ),
        );
        continue;
      }
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

  // shortcut: one PROPFIND per shared note per pass; batch them on a parent
  // folder if an account holds many shared notes.
  Future<void> _pullShared(SharingClient sharing, LocalNote row) async {
    final SharedStat stat;
    try {
      stat = await sharing.stat(row.davPath!);
    } on NotesHttpException catch (e) {
      if (e.statusCode != 404) rethrow;
      // Unshared or deleted by the owner; the next share listing decides.
      return;
    }
    if (stat.etag == row.etag && stat.writable == !row.readonly) return;
    final file = await sharing.read(row.davPath!);
    await (database.update(
      database.localNotes,
    )..where((n) => n.id.equals(row.id) & n.syncState.equals('clean'))).write(
      LocalNotesCompanion(
        content: Value(file.content),
        baseContent: Value(file.content),
        etag: Value(file.etag),
        readonly: Value(!stat.writable),
        revision: Value(row.revision + 1),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  /// Same states as [_push]: sending, needsDecision, or clean after the
  /// receipt, and the line merge after a rejected If-Match. Only the text is
  /// sent; a shared file cannot be renamed or moved from here.
  Future<void> _pushShared(
    SharingClient sharing,
    LocalNote selected, {
    bool retry = true,
  }) async {
    // Offline this throws before an operation exists: the edit stays a draft.
    await sharing.stat(selected.davPath!);
    final operation = await database.transaction(() async {
      final current = await database.note(selected.accountId, selected.id);
      if (current == null || current.syncState != 'draft') return null;
      final open =
          await (database.select(database.operations)..where(
                (o) =>
                    o.noteId.equals(current.id) &
                    o.state.isNotIn(['done', 'dismissed']),
              ))
              .get();
      if (open.isNotEmpty || current.readonly) return null;
      if (current.content == current.baseContent) {
        await (database.update(database.localNotes)
              ..where((n) => n.id.equals(current.id)))
            .write(const LocalNotesCompanion(syncState: Value('clean')));
        return null;
      }
      final id = const Uuid().v4();
      await database
          .into(database.operations)
          .insert(
            OperationsCompanion.insert(
              id: id,
              accountId: current.accountId,
              noteId: current.id,
              revision: current.revision,
              kind: 'update',
              payload: jsonEncode({
                'remoteId': current.remoteId,
                'etag': current.etag,
                'path': current.davPath,
                'title': current.baseTitle ?? '',
                'content': current.content,
                'category': current.baseCategory ?? '',
                'favorite': current.baseFavorite ?? false,
                'fields': {'content': current.content},
              }),
              state: const Value('sending'),
            ),
          );
      await (database.update(database.localNotes)
            ..where((n) => n.id.equals(current.id)))
          .write(const LocalNotesCompanion(syncState: Value('sending')));
      return (database.select(
        database.operations,
      )..where((o) => o.id.equals(id))).getSingle();
    });
    if (operation == null) return;
    final intent = jsonDecode(operation.payload) as Map<String, Object?>;
    final path = intent['path']! as String;
    final content = intent['content']! as String;
    RemoteNote result(String etag, String text) => RemoteNote(
      id: intent['remoteId']! as int,
      etag: etag,
      title: intent['title']! as String,
      content: text,
      category: intent['category']! as String,
      favorite: intent['favorite']! as bool,
      readonly: false,
      modified: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
    try {
      final etag = intent['etag'];
      if (etag is! String) {
        await _decision(operation, 'missing_etag');
        return;
      }
      await _receipt(
        operation,
        result(await sharing.write(path, content, etag: etag), content),
        intent,
      );
    } on SharedConflict {
      // The file changed since it was read; 412 wrote nothing.
      final SharedFile file;
      try {
        file = await sharing.read(path);
      } catch (_) {
        await _requeue(operation, 'offline');
        return;
      }
      final current = await database.note(
        operation.accountId,
        operation.noteId,
      );
      if (current != null &&
          await _rebase(operation, _sharedRemote(current, file))) {
        if (retry) await _pushShared(sharing, selected, retry: false);
        return;
      }
      await _decision(operation, 'remote_conflict');
    } catch (e) {
      // A failed write can still have been applied: read the file again.
      final SharedFile file;
      try {
        file = await sharing.read(path);
      } on NotesHttpException catch (read) {
        await _decision(
          operation,
          read.statusCode == 404 ? 'remote_deleted' : 'write_outcome_unknown',
        );
        return;
      } catch (_) {
        await _decision(operation, 'write_outcome_unknown');
        return;
      }
      if (file.etag == intent['etag']) {
        await _requeue(operation, _reason(e));
      } else if (file.content == content) {
        await _receipt(operation, result(file.etag, content), intent);
      } else {
        await _decision(operation, 'write_outcome_unknown');
      }
    }
  }

  Future<void> _decision(
    Operation operation,
    String code,
  ) => database.transaction(() async {
    if (await database.account(operation.accountId) == null) return;
    await (database.update(database.operations)
          ..where((o) => o.id.equals(operation.id) & o.state.equals('sending')))
        .write(
          OperationsCompanion(
            state: const Value('needsDecision'),
            errorCode: Value(code),
          ),
        );
    await (database.update(database.localNotes)
          ..where((n) => n.id.equals(operation.noteId)))
        .write(const LocalNotesCompanion(syncState: Value('needsDecision')));
  });

  Future<void> _receipt(
    Operation operation,
    NoteRecord result,
    Map<String, Object?> intent,
  ) => database.transaction(() async {
    final account = await database.account(operation.accountId);
    final current = await database.note(operation.accountId, operation.noteId);
    if (account == null || current == null) return;
    final live = await (database.select(
      database.operations,
    )..where((o) => o.id.equals(operation.id))).getSingleOrNull();
    if (live == null || live.state != 'sending') return;
    final collision =
        await (database.select(database.localNotes)..where(
              (n) =>
                  n.accountId.equals(operation.accountId) &
                  n.remoteId.equals(result.id) &
                  n.id.equals(current.id).not(),
            ))
            .getSingleOrNull();
    if (collision != null) {
      // Preserve a fetched row with its own edits as a separate recovery copy.
      if (collision.syncState != 'clean') {
        await (database.update(
          database.localNotes,
        )..where((n) => n.id.equals(collision.id))).write(
          const LocalNotesCompanion(
            remoteId: Value(null),
            etag: Value(null),
            syncState: Value('needsDecision'),
          ),
        );
      } else {
        await (database.delete(
          database.localNotes,
        )..where((n) => n.id.equals(collision.id))).go();
      }
    }
    await (database.update(
      database.accounts,
    )..where((a) => a.id.equals(account.id))).write(
      AccountsCompanion(mutationEpoch: Value(account.mutationEpoch + 1)),
    );
    // The title is the server's file name: on CREATE it may fill an empty
    // title or add "(2)" to a taken one. That is an accepted outcome.
    // Also on a rename: the server may add "(2)" when the name is taken.
    // A category is a folder path the server cleans the same way (`a//b`).
    final sent = intent['fields'] as Map<String, Object?>? ?? const {};
    final create = operation.kind == 'create';
    final named = create || sent.containsKey('title');
    final moved = create || sent.containsKey('category');
    final matches =
        result is RemoteNote &&
        (named || result.title == intent['title']) &&
        result.content == intent['content'] &&
        (moved || result.category == intent['category']) &&
        result.favorite == intent['favorite'];
    final adoptTitle =
        named &&
        result is RemoteNote &&
        (current.title == intent['title'] || current.title.trim().isEmpty);
    final adoptCategory =
        moved && result is RemoteNote && current.category == intent['category'];
    await (database.update(
      database.localNotes,
    )..where((n) => n.id.equals(current.id))).write(
      LocalNotesCompanion(
        remoteId: Value(result.id),
        title: adoptTitle ? Value(result.title) : const Value.absent(),
        category: adoptCategory ? Value(result.category) : const Value.absent(),
        etag: result is RemoteNote ? Value(result.etag) : const Value.absent(),
        baseTitle: result is RemoteNote
            ? Value(result.title)
            : const Value.absent(),
        baseContent: result is RemoteNote
            ? Value(result.content)
            : const Value.absent(),
        baseCategory: result is RemoteNote
            ? Value(result.category)
            : const Value.absent(),
        baseFavorite: result is RemoteNote
            ? Value(result.favorite)
            : const Value.absent(),
        readonly: result is RemoteNote
            ? Value(result.readonly)
            : const Value.absent(),
        syncState: Value(
          matches
              ? (current.revision == operation.revision ? 'clean' : 'draft')
              : 'needsDecision',
        ),
      ),
    );
    await (database.update(
      database.operations,
    )..where((o) => o.id.equals(operation.id))).write(
      OperationsCompanion(
        state: Value(matches ? 'done' : 'needsDecision'),
        errorCode: Value(matches ? null : 'receipt_differs_from_intent'),
      ),
    );
  });
}

/// The file name the Notes server derives from [content]
/// (`NoteUtil::stripMarkdown` and `getSafeTitle`): first line without
/// Markdown marks, `* | / \ : " < > ?` and leading dots, at most 100
/// characters. Empty when the text has no usable line.
String titleFromContent(String content) {
  final text = content
      .replaceAll(RegExp(r'^\s*[*+-]\s+', multiLine: true), '')
      .replaceAllMapped(
        RegExp(r'^#+\s+(.*?)\s*#*$', multiLine: true),
        (m) => m[1]!,
      )
      .replaceAll(RegExp(r'^(=+|-+)$', multiLine: true), '')
      .replaceAllMapped(
        RegExp(r'(\*+|_+)(.*?)\1', multiLine: true),
        (m) => m[2]!,
      )
      .replaceAll(RegExp(r'[*|/\\:"<>?]'), '')
      .replaceAll(RegExp(r'^[.\s]+', multiLine: true), '')
      .trim();
  final line = text
      .split(RegExp(r'\r\n|\n|\r'))
      .first
      .trim()
      .replaceAll(RegExp(r'\s'), ' ');
  final runes = line.runes.toList();
  return runes.length > 100
      ? String.fromCharCodes(runes.take(100)).trim()
      : line;
}
