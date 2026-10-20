import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:notes_protocol/notes_protocol.dart';
import 'package:notes_store/notes_store.dart';
import 'package:test/test.dart';

Map<String, Object> remote(int id, {String content = 'text', String? etag}) => {
  'id': id,
  'etag': etag ?? 'etag1',
  'title': 'Title $id',
  'content': content,
  'category': '',
  'favorite': false,
  'readonly': false,
  'modified': 10,
};
http.Response json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

void main() {
  late NotesDatabase db;
  setUp(() async {
    db = NotesDatabase(NativeDatabase.memory());
    await db
        .into(db.accounts)
        .insert(
          AccountsCompanion.insert(
            id: 'a',
            server: 'https://cloud.test/',
            loginName: 'user',
            credentialRef: 'secret',
          ),
        );
  });
  tearDown(() => db.close());

  SyncCoordinator coordinator(
    Future<http.Response> Function(http.Request) handle, {
    Future<String?> Function(Account)? scope,
    NotesDatabase? on,
  }) => SyncCoordinator(
    on ?? db,
    (_) async => NotesClient(
      base: ServerBase.parse('https://cloud.test'),
      transport: MockClient(handle),
      loginName: 'user',
      appPassword: 'secret',
    ),
    scopeFor: scope,
  );

  /// A clean synced note with remote id [remoteId].
  Future<LocalNote> synced(int remoteId, {String content = 'text'}) async {
    await db.applyPull('a', await db.readEpoch('a'), [
      parseNote(remote(remoteId, content: content)),
    ]);
    return (await (db.select(
      db.localNotes,
    )..where((n) => n.remoteId.equals(remoteId))).getSingle());
  }

  group('sync status survives a restart', () {
    test('problem, last check and counts come back from disk', () async {
      final dir = await Directory.systemTemp.createTemp('ownnotes-status-');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/notes.sqlite');
      final first = NotesDatabase(NativeDatabase(file));
      await first
          .into(first.accounts)
          .insert(
            AccountsCompanion.insert(
              id: 'a',
              server: 's',
              loginName: 'u',
              credentialRef: 'c',
            ),
          );
      final draft = await first.createDraft('a', content: 'unsent');
      final offline = coordinator((r) async {
        throw http.ClientException('down');
      }, on: first);
      await expectLater(offline.sync('a'), throwsA(anything));
      expect(offline.problem('a'), 'offline');
      await first.close();

      final reopened = NotesDatabase(NativeDatabase(file));
      addTearDown(reopened.close);
      final status = await reopened.syncStatus('a');
      expect(status.problem, 'offline');
      expect(status.lastCheckedAt, isNull);
      expect(status.pendingUploads, 1);
      // A fresh coordinator knows the problem before it syncs.
      final again = coordinator((r) async => json([]), on: reopened);
      await again.recoverInterruptedWrites();
      expect(again.problem('a'), 'offline');

      await again.sync('a');
      final healed = await reopened.syncStatus('a');
      expect(healed.problem, isNull);
      expect(healed.lastCheckedAt, isNotNull);
      expect(healed.pendingUploads, 0);
      expect(
        (await reopened.note('a', draft))!.syncState,
        anyOf('clean', 'needsDecision', 'draft', 'sending'),
      );
    });

    test(
      'the stream follows decisions, deletions and unreadable notes',
      () async {
        final events = <AccountSyncStatus>[];
        final sub = db.watchSyncStatus('a').listen(events.add);
        addTearDown(sub.cancel);
        await pumpEventQueue();
        expect(events.last.needsAttention, 0);
        final note = await synced(5);
        await db.markDeleted('a', note.id);
        await pumpEventQueue();
        expect(events.last.pendingDeletions, 1);
        expect(events.last.failedDeletions, 0);
        await db.applyPull('a', 0, [const UnreadableNote(6)]);
        await pumpEventQueue();
        expect(events.last.unreadable, 1);
        expect(events.last.needsAttention, 1);
      },
    );
  });

  group('deletions stay visible', () {
    test('a refused deletion keeps the note, the reason and Undo', () async {
      final note = await synced(40);
      await db.markDeleted('a', note.id);
      final sync = coordinator((r) async {
        if (r.method == 'DELETE') return http.Response('', 500);
        if (r.url.pathSegments.last == '40') return json(remote(40));
        return json([remote(40)]);
      });
      await sync.sync('a');
      final row = (await db.note('a', note.id))!;
      expect(row.syncState, 'deleting');
      expect(row.deleteError, 'server');
      expect(sync.problem('a'), 'server');
      final status = await db.syncStatus('a');
      expect(status.failedDeletions, 1);
      expect(status.problem, 'server');

      final feed = AttentionFeed(db);
      final items = await feed.watch('a').first;
      expect(items.single.kind, AttentionKind.failedDeletion);
      expect(items.single.reason, 'server');
      expect(items.single.note!.content, 'text');

      // Undo before the server confirmed it.
      expect(await db.undoDelete('a', note.id), isTrue);
      final back = (await db.note('a', note.id))!;
      expect(back.syncState, 'draft');
      expect(back.deleteError, isNull);
      expect(await db.select(db.recoveryCopies).get(), isEmpty);
      expect(await db.undoDelete('a', note.id), isFalse);
    });

    test('a transport failure is kept as the reason and retried', () async {
      final note = await synced(41);
      await db.markDeleted('a', note.id);
      var online = false;
      final deletes = <String>[];
      final sync = coordinator((r) async {
        if (r.method == 'DELETE') deletes.add(r.url.pathSegments.last);
        if (!online && r.url.pathSegments.last == '41') {
          throw http.ClientException('down');
        }
        if (r.method == 'GET' && r.url.pathSegments.last == '41') {
          return json(remote(41));
        }
        return json(r.method == 'DELETE' ? [] : [remote(41)]);
      });
      await expectLater(sync.sync('a'), throwsA(anything));
      expect((await db.note('a', note.id))!.deleteError, 'offline');
      online = true;
      await sync.retryDeletion('a', note.id);
      expect(deletes, ['41']);
      expect(await db.note('a', note.id), isNull);
      // The text of a deleted note stays recoverable.
      final copy = (await db.select(db.recoveryCopies).get()).single;
      expect(copy.kind, 'deleted');
      expect(copy.content, 'text');
    });

    test('a pending deletion is listed before the sync runs', () async {
      final note = await synced(42);
      await db.markDeleted('a', note.id);
      final items = await AttentionFeed(db).watch('a').first;
      expect(items.single.kind, AttentionKind.pendingDeletion);
      expect(items.single.noteId, note.id);
    });
  });

  group('unreadable notes', () {
    test(
      'an existing copy is kept and marked, new ones get a placeholder',
      () async {
        final known = await synced(7, content: 'old text');
        await db.applyPull('a', 0, [
          const UnreadableNote(7),
          const UnreadableNote(8),
        ]);
        final marked = (await db.note('a', known.id))!;
        expect(marked.unreadable, isTrue);
        expect(marked.content, 'old text');
        final placeholder = await (db.select(
          db.localNotes,
        )..where((n) => n.remoteId.equals(8))).getSingle();
        expect(placeholder.syncState, 'unreadable');
        // The placeholder cannot be edited, which would upload an empty text.
        await expectLater(
          db.saveDraft(
            accountId: 'a',
            id: placeholder.id,
            revision: placeholder.revision,
            title: '',
            content: 'x',
            category: '',
            favorite: false,
          ),
          throwsStateError,
        );
        final items = await AttentionFeed(db).watch('a').first;
        expect(
          items.map((i) => i.kind),
          everyElement(AttentionKind.unreadable),
        );
        expect(items, hasLength(2));
      },
    );

    test(
      'the next readable pull clears the marker, a full pull is forced',
      () async {
        await synced(7, content: 'old text');
        var readable = false;
        var pruned = <String?>[];
        final sync = coordinator((r) async {
          pruned.add(r.url.queryParameters['pruneBefore']);
          return json(
            readable
                ? [remote(7, content: 'new text', etag: 'etag2')]
                : [
                    {'id': 7, 'error': true},
                  ],
          );
        });
        await sync.sync('a');
        expect((await db.syncStatus('a')).unreadable, 1);
        readable = true;
        await sync.sync('a');
        final row = await (db.select(db.localNotes)).getSingle();
        expect(row.unreadable, isFalse);
        expect(row.content, 'new text');
        expect(pruned.where((p) => p != null), isEmpty);
      },
    );

    test('a placeholder goes when the note is gone from the server', () async {
      await db.applyPull('a', 0, [
        const UnreadableNote(8),
        parseNote(remote(1)),
      ]);
      await db.census('a', 0, {1});
      final rows = await db.select(db.localNotes).get();
      expect(rows.map((r) => r.remoteId), [1]);
    });
  });

  group('census safety', () {
    test('a plain disappearance deletes the row and keeps a copy', () async {
      final gone = await synced(1, content: 'precious');
      await synced(2);
      expect(await db.census('a', 0, {2}, scope: '/Notes|.md'), 0);
      expect(await db.note('a', gone.id), isNull);
      final copy = (await db.select(db.recoveryCopies).get()).single;
      expect(copy.kind, 'removed');
      expect(copy.content, 'precious');
      expect(copy.reason, 'missing_on_server');
    });

    test('a changed Notes folder keeps the offline copy', () async {
      final a = await synced(1, content: 'one');
      final b = await synced(2, content: 'two');
      await db.census('a', 0, {1, 2}, scope: '/Notes|.md');
      // The folder setting changed and the listing is another folder's.
      expect(await db.census('a', 0, {99}, scope: '/Other|.md'), 2);
      final rowA = (await db.note('a', a.id))!;
      expect(rowA.content, 'one');
      expect(rowA.missingSince, isNotNull);
      expect((await db.note('a', b.id))!.missingSince, isNotNull);
      expect((await db.select(db.recoveryCopies).get()), hasLength(2));
      expect((await db.syncStatus('a')).missing, 2);
      // Later passes with the same scope leave them alone.
      expect(await db.census('a', 0, {99}, scope: '/Other|.md'), 0);
      expect(await db.note('a', a.id), isNotNull);
      // If the note is listed again it is an ordinary note again.
      await db.applyPull('a', 0, [const NoteIdOnly(1)]);
      expect((await db.note('a', a.id))!.missingSince, isNull);
    });

    test('an empty listing does not wipe the offline copy', () async {
      await synced(1);
      expect(await db.census('a', 0, {}), 1);
      expect(
        (await db.select(db.localNotes).get()).single.missingSince,
        isNotNull,
      );
    });

    test(
      'through the coordinator: scope read, kept, then owner decides',
      () async {
        await synced(1, content: 'mine');
        var folder = '/Notes';
        var listing = <Map<String, Object>>[remote(1, content: 'mine')];
        final sync = coordinator(
          (r) async => json(listing),
          scope: (_) async => folder,
        );
        await sync.sync('a');
        folder = '/Archive';
        listing = [remote(2)];
        await sync.sync('a');
        final kept = await (db.select(
          db.localNotes,
        )..where((n) => n.remoteId.equals(1))).getSingle();
        expect(kept.missingSince, isNotNull);
        expect(kept.content, 'mine');
        final recovery = NoteRecovery(db);
        await recovery.keepMissingAsNew(kept);
        final detached = (await db.note('a', kept.id))!;
        expect(detached.remoteId, isNull);
        expect(detached.syncState, 'draft');
        expect(detached.missingSince, isNull);
        // A second missing note can be removed; its copy remains.
        final other = await synced(9, content: 'other');
        await db.census('a', await db.readEpoch('a'), {2}, scope: '/Elsewhere');
        await recovery.removeMissing((await db.note('a', other.id))!);
        expect(await db.note('a', other.id), isNull);
        final kinds = (await db.select(db.recoveryCopies).get()).map(
          (c) => c.content,
        );
        expect(kinds, contains('other'));
      },
    );
  });

  group('conflict resolution', () {
    Future<(LocalNote, RemoteNote)> conflict() async {
      final base = await synced(7, content: 'base');
      await db.saveConflict(
        accountId: 'a',
        id: base.id,
        revision: base.revision,
        title: base.title,
        content: 'device',
        category: '',
        favorite: false,
      );
      await db
          .into(db.operations)
          .insert(
            OperationsCompanion.insert(
              id: 'op',
              accountId: 'a',
              noteId: base.id,
              revision: 2,
              kind: 'update',
              payload: '{}',
              state: const Value('needsDecision'),
              errorCode: const Value('remote_conflict'),
            ),
          );
      final note = (await db.note('a', base.id))!;
      return (
        note,
        parseNote(remote(7, content: 'server', etag: 'etag2')) as RemoteNote,
      );
    }

    test('both originals stay until the owner discards them', () async {
      final (note, server) = await conflict();
      final recovery = NoteRecovery(db);
      expect(await recovery.reason(note), 'remote_conflict');
      final outcome = await recovery.resolve(
        expected: note,
        inspected: server,
        readServer: () async => server,
        choice: ConflictChoice.result,
        content: 'device\nserver',
      );
      expect(outcome.status, ConflictStatus.applied);
      final row = (await db.note('a', note.id))!;
      expect(row.content, 'device\nserver');
      expect(row.syncState, 'draft');
      expect(row.etag, 'etag2');
      final copies = await recovery.watchCopies('a').first;
      expect(
        {for (final c in copies) c.kind: c.content},
        {'device': 'device', 'server': 'server'},
      );
      await recovery.discardCopy('a', copies.first.id);
      expect(await recovery.watchCopies('a').first, hasLength(1));
      final restored = await recovery.restoreCopy('a', copies.last.id);
      expect((await db.note('a', restored))!.content, copies.last.content);
    });

    test('a stale server revision applies nothing', () async {
      final (note, server) = await conflict();
      final recovery = NoteRecovery(db);
      final newer =
          parseNote(remote(7, content: 'server again', etag: 'etag3'))
              as RemoteNote;
      final outcome = await recovery.resolve(
        expected: note,
        inspected: server,
        readServer: () async => newer,
        choice: ConflictChoice.server,
      );
      expect(outcome.status, ConflictStatus.serverChanged);
      expect(outcome.server!.content, 'server again');
      final row = (await db.note('a', note.id))!;
      expect(row.content, 'device');
      expect(row.syncState, 'needsDecision');
      // The version found is retained too.
      expect(
        (await db.select(db.recoveryCopies).get()).map((c) => c.content),
        containsAll(['device', 'server', 'server again']),
      );
    });

    test('server deletion and permission loss are separate outcomes', () async {
      final (note, server) = await conflict();
      final recovery = NoteRecovery(db);
      final gone = await recovery.resolve(
        expected: note,
        inspected: server,
        readServer: () async => null,
        choice: ConflictChoice.result,
      );
      expect(gone.status, ConflictStatus.serverDeleted);
      final readonly = RemoteNote(
        id: 7,
        etag: 'etag2',
        title: 'T',
        content: 'server',
        category: '',
        favorite: false,
        readonly: true,
        modified: 1,
      );
      final lost = await recovery.resolve(
        expected: note,
        inspected: readonly,
        readServer: () async => readonly,
        choice: ConflictChoice.result,
        content: 'device',
      );
      expect(lost.status, ConflictStatus.permissionLost);
      expect((await db.note('a', note.id))!.syncState, 'needsDecision');
      // The way out: an owned copy; the original is archived, not lost.
      final copy = await recovery.copyAsNew(note);
      expect((await db.note('a', copy))!.content, 'device');
    });

    test('a read error applies nothing and keeps the originals', () async {
      final (note, server) = await conflict();
      final recovery = NoteRecovery(db);
      await expectLater(
        recovery.resolve(
          expected: note,
          inspected: server,
          readServer: () async => throw const NotesTransportException(),
          choice: ConflictChoice.server,
        ),
        throwsA(isA<NotesTransportException>()),
      );
      expect((await db.note('a', note.id))!.content, 'device');
      expect(await db.select(db.recoveryCopies).get(), hasLength(2));
    });

    test('an unfinished Result is remembered', () async {
      final (note, _) = await conflict();
      final recovery = NoteRecovery(db);
      await recovery.saveResult(note, 'half done');
      await recovery.saveResult(note, 'more done');
      expect(await recovery.savedResult(note), 'more done');
      expect(await recovery.watchCopies('a').first, isEmpty);
    });

    test('the attachment move guard has an exit that does not loop', () async {
      // The note changed its category and holds an attachment: the sync
      // refuses to send the move. Keeping the server's category sends the
      // text only, and does not meet the guard again.
      final base = await synced(7, content: 'img ![](.attachments.7/a.png)');
      await db.saveDraft(
        accountId: 'a',
        id: base.id,
        revision: base.revision,
        title: base.title,
        content: 'img ![](.attachments.7/a.png) edit',
        category: 'Moved',
        favorite: false,
      );
      final puts = <Map<String, Object?>>[];
      final sync = coordinator((r) async {
        if (r.method == 'PUT') {
          puts.add(jsonDecode(r.body) as Map<String, Object?>);
          return json(
            remote(7, content: puts.last['content']! as String, etag: 'e2'),
          );
        }
        return json(r.url.pathSegments.last == '7' ? remote(7) : [remote(7)]);
      });
      await sync.sync('a');
      final stuck = (await db.note('a', base.id))!;
      expect(stuck.syncState, 'needsDecision');
      final recovery = NoteRecovery(db);
      expect(await recovery.reason(stuck), 'move_integrity_required');
      final server =
          parseNote(remote(7, content: 'img ![](.attachments.7/a.png)'))
              as RemoteNote;
      final outcome = await recovery.resolve(
        expected: stuck,
        inspected: server,
        readServer: () async => server,
        choice: ConflictChoice.result,
        category: server.category,
      );
      expect(outcome.status, ConflictStatus.applied);
      await sync.sync('a');
      expect(puts.single.keys, isNot(contains('category')));
      expect((await db.note('a', base.id))!.syncState, 'clean');
    });
  });

  group('crash and retry', () {
    test(
      'a write interrupted by a crash becomes a decision, nothing replays',
      () async {
        final note = await synced(3, content: 'base');
        await db.saveDraft(
          accountId: 'a',
          id: note.id,
          revision: note.revision,
          title: note.title,
          content: 'edited',
          category: '',
          favorite: false,
        );
        var puts = 0;
        Future<http.Response> handle(http.Request r) async {
          if (r.method == 'PUT') puts++;
          return json([remote(3)]);
        }

        // The first process died after it stored the operation as sending.
        await db.transaction(() async {
          await db
              .into(db.operations)
              .insert(
                OperationsCompanion.insert(
                  id: 'crashed',
                  accountId: 'a',
                  noteId: note.id,
                  revision: note.revision + 1,
                  kind: 'update',
                  payload: '{}',
                  state: const Value('sending'),
                ),
              );
          await (db.update(db.localNotes)..where((n) => n.id.equals(note.id)))
              .write(const LocalNotesCompanion(syncState: Value('sending')));
        });
        final restarted = coordinator(handle);
        await restarted.recoverInterruptedWrites();
        await restarted.sync('a');
        expect(puts, 0);
        final row = (await db.note('a', note.id))!;
        expect(row.syncState, 'needsDecision');
        expect(row.content, 'edited');
        final items = await AttentionFeed(db).watch('a').first;
        expect(items.single.kind, AttentionKind.decision);
        expect(items.single.reason, 'interrupted_write');
        expect((await db.syncStatus('a')).decisions, 1);
      },
    );

    test('local save failures are reported, listed and cleared', () async {
      final feed = AttentionFeed(db);
      final seen = <List<AttentionItem>>[];
      final sub = feed.watch('a').listen(seen.add);
      addTearDown(sub.cancel);
      await pumpEventQueue();
      feed.reportSaveFailure('a', 'n1', 'disk_full');
      await pumpEventQueue();
      expect(seen.last.single.kind, AttentionKind.saveFailure);
      expect(seen.last.single.reason, 'disk_full');
      feed.clearSaveFailure('a', 'n1');
      await pumpEventQueue();
      expect(seen.last, isEmpty);
    });
  });

  test('compareBlocks maps changed lines on both sides', () {
    expect(compareBlocks('a\nb', 'a\nb'), isEmpty);
    expect(compareBlocks('a\nb\nc\nd', 'a\nX\nY\nc\nd\ne'), [
      (deviceStart: 1, deviceEnd: 2, serverStart: 1, serverEnd: 3),
      (deviceStart: 4, deviceEnd: 4, serverStart: 5, serverEnd: 6),
    ]);
    expect(compareBlocks('a\nb', 'a'), [
      (deviceStart: 1, deviceEnd: 2, serverStart: 1, serverEnd: 1),
    ]);
  });

  test(
    'a v3 database gains the status and recovery tables with its data',
    () async {
      final dir = await Directory.systemTemp.createTemp('ownnotes-v3-');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/notes.sqlite');
      final first = NotesDatabase(NativeDatabase(file));
      await first
          .into(first.accounts)
          .insert(
            AccountsCompanion.insert(
              id: 'a',
              server: 's',
              loginName: 'u',
              credentialRef: 'c',
            ),
          );
      final id = await first.createDraft('a', content: 'kept through upgrade');
      await first.customStatement('DROP TABLE sync_statuses');
      await first.customStatement('DROP TABLE recovery_copies');
      for (final c in ['delete_error', 'unreadable', 'missing_since']) {
        await first.customStatement('ALTER TABLE local_notes DROP COLUMN $c');
      }
      await first.customStatement('PRAGMA user_version = 3');
      await first.close();

      final upgraded = NotesDatabase(NativeDatabase(file));
      addTearDown(upgraded.close);
      final note = (await upgraded.note('a', id))!;
      expect(note.content, 'kept through upgrade');
      expect(note.deleteError, isNull);
      expect(note.unreadable, isNot(true));
      expect(note.missingSince, isNull);
      await upgraded.recordSyncResult('a', completed: true, problem: 'auth');
      final status = await upgraded.syncStatus('a');
      expect(status.problem, 'auth');
      expect(status.lastCheckedAt, isNotNull);
      await upgraded.keepCopy(note, 'device');
      expect(
        await upgraded.select(upgraded.recoveryCopies).get(),
        hasLength(1),
      );
      // Removing the account takes its status and copies along.
      await (upgraded.delete(upgraded.accounts)).go();
      expect(await upgraded.select(upgraded.syncStatuses).get(), isEmpty);
      expect(await upgraded.select(upgraded.recoveryCopies).get(), isEmpty);
    },
  );
}
