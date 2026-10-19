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
    final account = await database.account(accountId);
    if (account == null) return;
    final client = await clientFor(account);
    final drafts =
        await (database.select(database.localNotes)..where(
              (n) =>
                  n.accountId.equals(accountId) & n.syncState.equals('draft'),
            ))
            .get();
    // A write that fails in transport cannot prove it was not applied and
    // becomes a decision. Send only right after the server answered, so an
    // offline edit stays a plain draft (and this throws to report offline).
    if (drafts.isNotEmpty) await client.list(chunkSize: 1);
    for (final draft in drafts) {
      if (await database.account(accountId) == null) return;
      await _push(client, draft);
    }
    if (await database.account(accountId) == null) return;
    final epoch = await database.readEpoch(accountId);
    String? cursor;
    final seenCursors = <String>{};
    do {
      final page = await client.list(cursor: cursor);
      if (!await database.applyPull(accountId, epoch, page.notes)) return;
      cursor = page.cursor;
      if (cursor != null && !seenCursors.add(cursor)) {
        throw const NotesProtocolException('repeated_chunk_cursor');
      }
    } while (cursor != null);
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
      final title = current.remoteId != null && current.title.isEmpty
          ? current.baseTitle ?? ''
          : current.title;
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
        // Moving existing attachment folders is not safely confirmed by a note
        // response alone. Keep such edits local until move recovery is available.
        if (fields.containsKey('category') || fields.containsKey('title')) {
          await _decision(operation, 'move_integrity_required');
          return;
        }
        result = await client.update(
          intent['remoteId']! as int,
          etag: etag,
          patch: NotePatch(
            content: fields['content'] as String?,
            favorite: fields['favorite'] as bool?,
          ),
        );
      }
      await _receipt(operation, result, intent);
    } on NoteConflict {
      await _decision(operation, 'remote_conflict');
    } catch (_) {
      // Even an HTTP error can follow a partially applied mutation.
      await _decision(operation, 'write_outcome_unknown');
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
    final create = operation.kind == 'create';
    final matches =
        result is RemoteNote &&
        (create || result.title == intent['title']) &&
        result.content == intent['content'] &&
        result.category == intent['category'] &&
        result.favorite == intent['favorite'];
    final adoptTitle =
        create && result is RemoteNote && current.title == intent['title'];
    await (database.update(
      database.localNotes,
    )..where((n) => n.id.equals(current.id))).write(
      LocalNotesCompanion(
        remoteId: Value(result.id),
        title: adoptTitle ? Value(result.title) : const Value.absent(),
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
