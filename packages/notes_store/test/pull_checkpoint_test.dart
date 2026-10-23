import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:notes_protocol/notes_protocol.dart';
import 'package:notes_store/notes_store.dart';
import 'package:notes_store/src/notes_pull.dart';
import 'package:notes_store/src/pull_checkpoint.dart';
import 'package:test/test.dart';

Map<String, Object> note(int id, {String content = 'original'}) => {
  'id': id,
  'etag': content,
  'title': 'Note',
  'content': content,
  'category': '',
  'favorite': false,
  'readonly': false,
  'modified': 10,
};

http.Response page(
  List<Object> notes, {
  int time = 100,
  String? etag,
  String? cursor,
}) => http.Response(
  jsonEncode(notes),
  200,
  headers: {
    'content-type': 'application/json',
    'last-modified': HttpDate.format(
      DateTime.fromMillisecondsSinceEpoch(time * 1000, isUtc: true),
    ),
    'etag': ?etag,
    'x-notes-chunk-cursor': ?cursor,
  },
);

typedef Handler = Future<http.Response> Function(http.Request);
NotesClient client(Handler handle, {int limit = 8388608}) => NotesClient(
  base: ServerBase.parse('https://cloud.test/'),
  transport: MockClient(handle),
  loginName: 'user',
  appPassword: 'secret',
  maxResponseBytes: limit,
);

Future<void> addAccount(NotesDatabase db) => db
    .into(db.accounts)
    .insert(
      AccountsCompanion.insert(
        id: 'a',
        server: 'https://cloud.test/',
        loginName: 'user',
        credentialRef: 'ref',
      ),
    );

void main() {
  late NotesDatabase db;
  setUp(() async {
    db = NotesDatabase(NativeDatabase.memory());
    await addAccount(db);
  });
  tearDown(() => db.close());

  Future<void> pull(
    Handler handle, {
    int limit = 8388608,
    String? scope = 'Notes|.md',
    bool force = false,
  }) => pullNotes(
    database: db,
    client: client(handle, limit: limit),
    accountId: 'a',
    keepLease: () async {},
    scopeFor: (_) async => scope,
    forceFull: force,
  );

  Future<void> warm() async {
    await pull((_) async => page([note(1)], time: 100, etag: '"page"'));
    await pull((r) async {
      expect(r.url.queryParameters['pruneBefore'], '100');
      expect(r.url.queryParameters['chunkSize'], '0');
      expect(r.headers['If-None-Match'], isNull);
      return page(
        [
          {'id': 1},
        ],
        time: 200,
        etag: 'W/"list"',
      );
    });
  }

  test(
    'watermark and exact validator query survive a database restart',
    () async {
      final dir = await Directory.systemTemp.createTemp('ownnotes-checkpoint-');
      final file = File('${dir.path}/notes.sqlite');
      await db.close();
      db = NotesDatabase(NativeDatabase(file));
      await addAccount(db);
      await warm();
      final before = await db.select(db.localNotes).getSingle();
      await db.close();
      db = NotesDatabase(NativeDatabase(file));
      final sync = SyncCoordinator(
        db,
        (_) async => client((r) async {
          expect(r.url.queryParameters, {
            'chunkSize': '0',
            'pruneBefore': '100',
          });
          expect(r.headers['If-None-Match'], 'W/"list"');
          return http.Response('', 304);
        }),
        scopeFor: (_) async => 'Notes|.md',
      );
      await sync.sync('a');
      expect(await db.select(db.localNotes).getSingle(), before);
      expect((await db.pullCheckpoint('a'))!.watermark, 200);
      expect(await db.select(db.recoveryCopies).get(), isEmpty);
      await db.close();
      db = NotesDatabase(NativeDatabase.memory());
      await dir.delete(recursive: true);
    },
  );

  test('a changed validator rotates to the new prune point', () async {
    await warm();
    await pull((r) async {
      expect(r.headers['If-None-Match'], 'W/"list"');
      return page([note(1, content: 'changed')], time: 300, etag: '"new"');
    });
    expect((await db.pullCheckpoint('a'))!.listEtag, isNull);
    expect((await db.select(db.localNotes).getSingle()).content, 'changed');
    await pull((r) async {
      expect(r.headers['If-None-Match'], isNull);
      expect(r.url.queryParameters['pruneBefore'], '300');
      return page(
        [
          {'id': 1},
        ],
        time: 400,
        etag: '"small"',
      );
    });
    expect((await db.pullCheckpoint('a'))!.listEtag, '"small"');
  });

  test('a first-page ETag cannot hide a later page', () async {
    var calls = 0;
    await pull((r) async {
      calls++;
      expect(r.headers['If-None-Match'], isNull);
      return calls == 1
          ? page([note(1)], etag: '"unchanged-first"', cursor: 'next')
          : page([note(2)], etag: '"last"');
    });
    expect(calls, 2);
    expect((await db.pullCheckpoint('a'))!.listEtag, isNull);
    expect(await db.storedRemoteIds('a'), {1, 2});
  });

  test('an unknown id in a pruned response requires a full replay', () async {
    await warm();
    var calls = 0;
    await pull((r) async {
      if (++calls == 1) {
        return page([
          {'id': 1},
          {'id': 2},
        ], time: 300);
      }
      expect(r.url.queryParameters, {'chunkSize': '100'});
      expect(r.headers['If-None-Match'], isNull);
      return page([note(1), note(2)], time: 301);
    });
    expect(calls, 2);
    expect(await db.storedRemoteIds('a'), {1, 2});
    expect((await db.pullCheckpoint('a'))!.watermark, 301);
  });

  test('a missing local row invalidates a stored validator', () async {
    await warm();
    await db.delete(db.localNotes).go();
    var calls = 0;
    await pull((r) async {
      expect(r.headers['If-None-Match'], isNull);
      if (++calls == 1) {
        return page([
          {'id': 1},
        ]);
      }
      return page([note(1)]);
    });
    expect(calls, 2);
    expect((await db.select(db.localNotes).getSingle()).content, 'original');
  });

  test('304 rechecks local membership after the request', () async {
    await warm();
    var calls = 0;
    await pull((r) async {
      if (++calls == 1) {
        await db.delete(db.localNotes).go();
        return http.Response('', 304);
      }
      expect(r.url.queryParameters, {'chunkSize': '100'});
      return page([note(1)]);
    });
    expect(calls, 2);
    expect(await db.storedRemoteIds('a'), {1});
  });

  test(
    'an interrupted paged pull keeps the old baseline without its ETag',
    () async {
      await warm();
      var calls = 0;
      await expectLater(
        pull((_) async {
          if (++calls == 1) {
            return page([note(1, content: 'new')], time: 300, cursor: 'next');
          }
          return http.Response('', 503);
        }),
        throwsA(isA<NotesHttpException>()),
      );
      final checkpoint = (await db.pullCheckpoint('a'))!;
      expect(checkpoint.watermark, 200);
      expect(checkpoint.listEtag, isNull);
      expect((await db.select(db.localNotes).getSingle()).content, 'new');
      await pull((r) async {
        expect(r.url.queryParameters['pruneBefore'], '200');
        expect(r.headers['If-None-Match'], isNull);
        return page([note(1, content: 'new'), note(2)], time: 400);
      });
      expect(await db.storedRemoteIds('a'), {1, 2});
    },
  );

  test('skipped dirty text cannot advance the checkpoint', () async {
    await warm();
    final local = await db.select(db.localNotes).getSingle();
    await db.saveDraft(
      accountId: 'a',
      id: local.id,
      revision: local.revision,
      title: local.title,
      content: 'my-edit',
      category: '',
      favorite: false,
    );
    await pull((_) async => page([note(1, content: 'server-edit')], time: 300));
    expect((await db.note('a', local.id))!.content, 'my-edit');
    expect((await db.pullCheckpoint('a'))!.watermark, 200);
    await db
        .update(db.localNotes)
        .write(const LocalNotesCompanion(syncState: Value('clean')));
    await pull((r) async {
      expect(r.url.queryParameters['pruneBefore'], '200');
      return page([note(1, content: 'server-edit')], time: 400);
    });
    expect((await db.note('a', local.id))!.content, 'server-edit');
  });

  test('an overlapping receipt fences both data and checkpoint', () async {
    await warm();
    await pull((_) async {
      await db
          .update(db.accounts)
          .write(const AccountsCompanion(mutationEpoch: Value(1)));
      return page([note(1, content: 'stale')], time: 300);
    });
    expect((await db.select(db.localNotes).getSingle()).content, 'original');
    expect((await db.pullCheckpoint('a'))!.watermark, 200);
    expect((await db.pullCheckpoint('a'))!.listEtag, isNull);
  });

  test(
    'a missing server date cannot replace the persisted watermark',
    () async {
      await warm();
      await pull(
        (_) async => http.Response(
          jsonEncode([note(1)]),
          200,
          headers: {'content-type': 'application/json', 'etag': '"no-date"'},
        ),
      );
      expect((await db.pullCheckpoint('a'))!.watermark, 200);
      expect((await db.pullCheckpoint('a'))!.listEtag, isNull);
    },
  );

  test(
    'an incomplete full replay cannot create a checkpoint or run census',
    () async {
      await db.applyPull('a', 0, [parseNote(note(1))]);
      await expectLater(
        pull(
          (_) async => page([
            {'id': 2},
          ]),
        ),
        throwsA(isA<NotesProtocolException>()),
      );
      expect(await db.pullCheckpoint('a'), isNull);
      expect(await db.storedRemoteIds('a'), {1});
    },
  );

  test('corrupt optional cache metadata falls back to a normal pull', () async {
    await warm();
    await db
        .update(db.pullCheckpoints)
        .write(const PullCheckpointsCompanion(remoteIds: Value('["invalid"]')));
    await pull((r) async {
      expect(r.headers['If-None-Match'], isNull);
      expect(r.url.queryParameters['pruneBefore'], '200');
      return page([note(1)], time: 300);
    });
    expect((await db.pullCheckpoint('a'))!.watermark, 300);
  });

  for (final scope in <String?>['Other|.txt', null]) {
    test('scope $scope requires a full listing', () async {
      await warm();
      await pull((r) async {
        expect(r.url.queryParameters, {'chunkSize': '100'});
        expect(r.headers['If-None-Match'], isNull);
        return page([note(1)], time: 300);
      }, scope: scope);
      expect(
        (await db.pullCheckpoint('a'))!.watermark,
        scope == null ? 200 : 300,
      );
    });
  }

  test('an account generation change requires a full listing', () async {
    await warm();
    await db
        .update(db.accounts)
        .write(const AccountsCompanion(generation: Value(2)));
    await pull((r) async {
      expect(r.url.queryParameters, {'chunkSize': '100'});
      return page([note(1)], time: 300);
    });
    expect((await db.pullCheckpoint('a'))!.generation, 2);
  });

  test('oversized unchunked response falls back to bounded pages', () async {
    await warm();
    var calls = 0;
    await pull((r) async {
      if (++calls == 1) return page([note(1, content: 'x' * 1000)]);
      expect(r.url.queryParameters['chunkSize'], '100');
      expect(r.url.queryParameters['pruneBefore'], '200');
      expect(r.headers['If-None-Match'], isNull);
      return page([note(1)], time: 300);
    }, limit: 500);
    expect(calls, 2);
    expect((await db.pullCheckpoint('a'))!.watermark, 300);
    expect((await db.pullCheckpoint('a'))!.listEtag, isNull);
  });

  test(
    'invalid 304 metadata falls back without deleting cached notes',
    () async {
      await warm();
      var calls = 0;
      await pull(
        (r) async => ++calls == 1
            ? http.Response('', 304, headers: {'etag': '"other"'})
            : page([note(1)], time: 300),
      );
      expect(calls, 2);
      expect(await db.storedRemoteIds('a'), {1});
    },
  );

  test('server clock regression forces a full listing', () async {
    await warm();
    var calls = 0;
    await pull((r) async {
      if (++calls == 1) {
        return page([
          {'id': 1},
        ], time: 50);
      }
      expect(r.url.queryParameters, {'chunkSize': '100'});
      return page([note(1, content: 'after-reset')], time: 51);
    });
    expect(calls, 2);
    expect((await db.pullCheckpoint('a'))!.watermark, 51);
  });

  test(
    'manual refresh during a running pull performs a full follow-up',
    () async {
      await warm();
      final requested = Completer<void>();
      final release = Completer<void>();
      var calls = 0;
      final sync = SyncCoordinator(
        db,
        (_) async => client((r) async {
          if (++calls == 1) {
            requested.complete();
            await release.future;
            return http.Response('', 304);
          }
          expect(r.url.queryParameters, {'chunkSize': '100'});
          return page([note(1)], time: 300);
        }),
        scopeFor: (_) async => 'Notes|.md',
      );
      final first = sync.sync('a');
      await requested.future;
      final second = sync.sync('a', relist: true);
      release.complete();
      await Future.wait([first, second]);
      expect(calls, 2);
      expect((await db.pullCheckpoint('a'))!.watermark, 300);
    },
  );

  test(
    'schema 5 upgrade preserves unsent text and creates an empty checkpoint table',
    () async {
      final dir = await Directory.systemTemp.createTemp('ownnotes-v5-');
      final file = File('${dir.path}/notes.sqlite');
      final old = NotesDatabase(NativeDatabase(file));
      await addAccount(old);
      final id = await old.createDraft('a', content: 'unsent text');
      await old.customStatement('DROP TABLE pull_checkpoints');
      await old.customStatement('PRAGMA user_version = 5');
      await old.close();
      final upgraded = NotesDatabase(NativeDatabase(file));
      try {
        expect((await upgraded.note('a', id))!.content, 'unsent text');
        expect((await upgraded.note('a', id))!.syncState, 'draft');
        expect(await upgraded.select(upgraded.pullCheckpoints).get(), isEmpty);
      } finally {
        await upgraded.close();
        await dir.delete(recursive: true);
      }
    },
  );

  test('removing an account cascades to its checkpoint', () async {
    await warm();
    await db.delete(db.accounts).go();
    expect(await db.select(db.pullCheckpoints).get(), isEmpty);
  });
}
