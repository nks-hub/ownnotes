import 'dart:async';
import 'dart:convert';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:notes_protocol/notes_protocol.dart';
import 'package:notes_store/notes_store.dart';
import 'package:test/test.dart';

Map<String, Object> remote(int id) => {
  'id': id,
  'etag': 'etag1',
  'title': 'Title',
  'content': 'local',
  'category': '',
  'favorite': false,
  'readonly': false,
  'modified': 10,
};
http.Response response(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json'},
);
void main() {
  late NotesDatabase db;
  late String id;
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
    id = await db.createDraft('a');
    await db.saveDraft(
      accountId: 'a',
      id: id,
      revision: 1,
      title: 'Title',
      content: 'local',
      category: '',
      favorite: false,
    );
  });
  tearDown(() => db.close());
  SyncCoordinator coordinator(
    Future<http.Response> Function(http.Request) handle,
  ) => SyncCoordinator(
    db,
    (_) async => NotesClient(
      base: ServerBase.parse('https://cloud.test'),
      transport: MockClient(handle),
      loginName: 'user',
      appPassword: 'secret',
    ),
  );
  test('receipt preserves edits during request and fences old reads', () async {
    final sent = Completer<void>();
    final receipt = Completer<http.Response>();
    final sync = coordinator((r) async {
      if (r.method == 'POST') {
        sent.complete();
        return receipt.future;
      }
      return response([remote(17)]);
    });
    final work = sync.sync('a');
    await sent.future;
    await db.saveDraft(
      accountId: 'a',
      id: id,
      revision: 2,
      title: 'Title',
      content: 'newer',
      category: '',
      favorite: false,
    );
    receipt.complete(response(remote(17)));
    await work;
    final note = (await db.note('a', id))!;
    expect(note.remoteId, 17);
    expect(note.content, 'newer');
    expect(note.baseContent, 'local');
    expect(note.syncState, 'draft');
    expect(await db.applyPull('a', 0, [parseNote(remote(99))]), isFalse);
  });
  test('CREATE accepts the file name the server chose', () async {
    // Empty title becomes "New note"; a taken name gets a "(2)" suffix.
    final untitled = await db.createDraft('a', content: 'text only');
    final stored = <Map<String, Object>>[];
    final sync = coordinator((r) async {
      if (r.method != 'POST') return response(stored);
      final sent = jsonDecode(r.body) as Map<String, Object?>;
      final note = {
        ...remote(sent['content'] == 'text only' ? 21 : 22),
        'title': sent['title'] == '' ? 'New note' : 'Title (2)',
        'content': sent['content']! as String,
      };
      stored.add(note);
      return response(note);
    });
    await sync.sync('a');
    final named = (await db.note('a', id))!;
    expect(named.syncState, 'clean');
    expect(named.title, 'Title (2)');
    final unnamed = (await db.note('a', untitled))!;
    expect(unnamed.syncState, 'clean');
    expect(unnamed.title, 'New note');
    expect(unnamed.baseTitle, 'New note');

    // An editor opened before the receipt still saves an empty title.
    await db.saveDraft(
      accountId: 'a',
      id: untitled,
      revision: unnamed.revision,
      title: '',
      content: 'more text',
      category: '',
      favorite: false,
    );
    final puts = <Map<String, Object?>>[];
    final updated = {
      ...remote(21),
      'etag': 'etag2',
      'title': 'New note',
      'content': 'more text',
    };
    await coordinator((r) async {
      if (r.method != 'PUT') {
        return response([updated, stored.firstWhere((n) => n['id'] == 22)]);
      }
      puts.add(jsonDecode(r.body) as Map<String, Object?>);
      return response(updated);
    }).sync('a');
    expect(puts.single.containsKey('title'), isFalse);
    expect((await db.note('a', untitled))!.syncState, 'clean');
  });
  group('rename', () {
    Future<LocalNote> edited(String content) async {
      await db.markDeleted('a', id);
      await db.applyPull('a', 0, [
        parseNote({...remote(50), 'content': content}),
      ]);
      final note = await (db.select(
        db.localNotes,
      )..where((n) => n.remoteId.equals(50))).getSingle();
      await db.saveDraft(
        accountId: 'a',
        id: note.id,
        revision: note.revision,
        title: 'Renamed',
        content: content,
        category: 'Work',
        favorite: false,
      );
      return note;
    }

    test('title and category changes are sent without attachments', () async {
      final note = await edited('plain text');
      final puts = <Map<String, Object?>>[];
      final renamed = {
        ...remote(50),
        'etag': 'etag2',
        'title': 'Renamed (2)',
        'category': 'Work',
        'content': 'plain text',
      };
      await coordinator((r) async {
        if (r.method == 'PUT') {
          puts.add(jsonDecode(r.body) as Map<String, Object?>);
          return response(renamed);
        }
        return response(puts.isEmpty ? [] : [renamed]);
      }).sync('a');
      expect(puts.single, {'title': 'Renamed', 'category': 'Work'});
      final stored = (await db.note('a', note.id))!;
      expect(stored.syncState, 'clean');
      expect(stored.title, 'Renamed (2)');
    });

    test('a note with attachments still asks before moving', () async {
      final note = await edited('![x](.attachments.50/x.png)');
      var puts = 0;
      await coordinator((r) async {
        if (r.method == 'PUT') puts++;
        return response([]);
      }).sync('a');
      expect(puts, 0);
      expect((await db.note('a', note.id))!.syncState, 'needsDecision');
    });
  });
  test('offline edits stay drafts instead of becoming decisions', () async {
    var online = false;
    var posts = 0;
    final sync = coordinator((r) async {
      if (!online) throw Exception('no network');
      if (r.method == 'POST') {
        posts++;
        return response(remote(31));
      }
      return response(posts == 0 ? [] : [remote(31)]);
    });
    await expectLater(sync.sync('a'), throwsA(isA<NotesTransportException>()));
    expect((await db.note('a', id))!.syncState, 'draft');
    expect(await db.select(db.operations).get(), isEmpty);
    online = true;
    await sync.sync('a');
    expect(posts, 1);
    expect((await db.note('a', id))!.syncState, 'clean');
  });
  group('delete', () {
    // A synced note with remote id 40, etag "etag1".
    Future<String> synced() async {
      await db.applyPull('a', 0, [parseNote(remote(40))]);
      final rows = await (db.select(
        db.localNotes,
      )..where((n) => n.remoteId.equals(40))).get();
      return rows.single.id;
    }

    test('a never uploaded note is removed locally only', () async {
      final requests = <String>[];
      await db.markDeleted('a', id);
      await coordinator((r) async {
        requests.add(r.method);
        return response([]);
      }).sync('a');
      expect(await db.note('a', id), isNull);
      expect(requests, ['GET']);
    });

    test('an unchanged note is deleted on the server', () async {
      await db.markDeleted('a', id);
      final note = await synced();
      await db.markDeleted('a', note);
      expect(await db.watchNotes('a').first, isEmpty);
      final requests = <String>[];
      await coordinator((r) async {
        requests.add('${r.method} ${r.url.pathSegments.last}');
        if (r.method == 'GET' && r.url.pathSegments.last == '40') {
          expect(r.headers['If-None-Match'], '"etag1"');
          return http.Response('', 304);
        }
        return response([]);
      }).sync('a');
      expect(requests, contains('DELETE 40'));
      expect(await db.note('a', note), isNull);
    });

    test('a note changed on the server comes back instead', () async {
      await db.markDeleted('a', id);
      final note = await synced();
      await db.markDeleted('a', note);
      var deletes = 0;
      final changed = {...remote(40), 'etag': 'etag2', 'content': 'newer'};
      await coordinator((r) async {
        if (r.method == 'DELETE') deletes++;
        if (r.url.pathSegments.last == '40') return response(changed);
        return response([changed]);
      }).sync('a');
      expect(deletes, 0);
      final restored = (await db.note('a', note))!;
      expect(restored.syncState, 'clean');
      expect(restored.content, 'newer');
    });

    test('a note gone from the server disappears unless edited', () async {
      final gone = await synced();
      await db.applyPull('a', 0, [parseNote(remote(41))]);
      final edited = (await (db.select(
        db.localNotes,
      )..where((n) => n.remoteId.equals(41))).getSingle());
      await db.saveDraft(
        accountId: 'a',
        id: edited.id,
        revision: edited.revision,
        title: 'Title',
        content: 'kept',
        category: '',
        favorite: false,
      );
      await db.markDeleted('a', id);
      await db.census('a', await db.readEpoch('a'), {});
      expect(await db.note('a', gone), isNull);
      expect((await db.note('a', edited.id))!.content, 'kept');
    });
  });
  test('lost CREATE response is never retried', () async {
    var creates = 0;
    Future<http.Response> handle(http.Request r) async {
      if (r.method == 'POST') {
        creates++;
        throw Exception('lost');
      }
      return response([]);
    }

    await coordinator(handle).sync('a');
    await coordinator(handle).sync('a');
    expect(creates, 1);
    expect((await db.note('a', id))!.syncState, 'needsDecision');
  });
  test('startup recovers sending operation without replay', () async {
    await db
        .into(db.operations)
        .insert(
          OperationsCompanion.insert(
            id: 'op',
            accountId: 'a',
            noteId: id,
            revision: 2,
            kind: 'create',
            payload: '{}',
            state: const Value('sending'),
          ),
        );
    var creates = 0;
    final sync = coordinator((r) async {
      if (r.method == 'POST') creates++;
      return response([]);
    });
    await sync.recoverInterruptedWrites();
    await sync.sync('a');
    expect(creates, 0);
    expect((await db.note('a', id))!.syncState, 'needsDecision');
  });
  test('CREATE binding merges already fetched remote row', () async {
    final sync = coordinator((r) async {
      if (r.method == 'POST') {
        await db.applyPull('a', 0, [parseNote(remote(17))]);
        return response(remote(17));
      }
      return response([remote(17)]);
    });
    await sync.sync('a');
    final rows = await db.select(db.localNotes).get();
    expect(rows.length, 1);
    expect(rows.single.id, id);
    expect(rows.single.syncState, 'clean');
  });
  test('late receipt cannot resurrect removed account', () async {
    final sync = coordinator((r) async {
      if (r.method != 'POST') return response([]);
      await (db.delete(db.accounts)..where((a) => a.id.equals('a'))).go();
      return response(remote(17));
    });
    await sync.sync('a');
    expect(await db.select(db.localNotes).get(), isEmpty);
    expect(await db.select(db.operations).get(), isEmpty);
  });
}
