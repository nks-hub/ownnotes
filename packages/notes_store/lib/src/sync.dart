import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:notes_protocol/notes_protocol.dart';
import 'package:uuid/uuid.dart';
import 'database.dart';

/// One foreground coordinator per database. Background workers are not enabled.
/// A persisted sending operation is never replayed automatically after a crash.
final class SyncCoordinator {
  SyncCoordinator(this.database, this.clientFor);
  final NotesDatabase database;
  final Future<NotesClient> Function(Account account) clientFor;
  final Map<String, Future<void>> _running = {};
  final Map<String, String> _problems = {};

  /// Why the last sync of [accountId] left notes unsent: `offline`, `auth`,
  /// `locked`, `storage_full` or `server`; null when nothing went wrong.
  String? problem(String accountId) => _problems[accountId];

  Future<void> sync(String accountId) {
    final existing = _running[accountId];
    if (existing != null) return existing;
    final result = _sync(accountId);
    _running[accountId] = result;
    return result.whenComplete(() => _running.remove(accountId));
  }

  /// Call once during startup, before accepting sync requests.
  Future<void> recoverInterruptedWrites() => database.transaction(() async {
    final interrupted = await (database.select(
      database.operations,
    )..where((o) => o.state.equals('sending'))).get();
    for (final operation in interrupted) {
      await _decision(operation, 'interrupted_write');
    }
  });

  Future<void> _sync(String accountId) async {
    _problems.remove(accountId);
    try {
      await _pass(accountId);
    } catch (e) {
      _problems[accountId] = _reason(e);
      rethrow;
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
                  n.accountId.equals(accountId) & n.syncState.equals('draft'),
            ))
            .get();
    final deletions =
        await (database.select(database.localNotes)..where(
              (n) =>
                  n.accountId.equals(accountId) &
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
      await _push(client, draft);
    }
    for (final note in deletions) {
      if (await database.account(accountId) == null) return;
      await _delete(client, note);
    }
    if (await database.account(accountId) == null) return;
    final epoch = await database.readEpoch(accountId);
    String? cursor;
    final seenCursors = <String>{};
    final listed = <int>{};
    do {
      final page = await client.list(cursor: cursor);
      if (!await database.applyPull(accountId, epoch, page.notes)) return;
      listed.addAll(page.notes.map((n) => n.id));
      cursor = page.cursor;
      if (cursor != null && !seenCursors.add(cursor)) {
        throw const NotesProtocolException('repeated_chunk_cursor');
      }
    } while (cursor != null);
    await database.census(accountId, epoch, listed);
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

  Future<void> _push(NotesClient client, LocalNote selected) async {
    final operation = await database.transaction(() async {
      final current = await database.note(selected.accountId, selected.id);
      if (current == null || current.syncState != 'draft' || current.readonly) {
        return null;
      }
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
    } on NoteConflict {
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
    final reason = _reason(error);
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
    return true;
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
