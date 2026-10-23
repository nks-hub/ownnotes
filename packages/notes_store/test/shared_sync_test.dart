import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:notes_protocol/notes_protocol.dart';
import 'package:notes_store/notes_store.dart';
import 'package:test/test.dart';

/// A tiny Nextcloud: one shared file served over WebDAV with ETag/If-Match,
/// the incoming share list, and an (empty) Notes API.
class FakeServer {
  String content = 'milk\nbread\neggs\n';
  int version = 1;
  int permissions = 3;
  int? listedPermissions;
  List<Map<String, Object?>> otherIncoming = [];
  bool shared = true;
  bool offline = false;
  int outgoingStatus = 200;
  Set<int> outgoing = {};
  Set<String> outgoingFolders = {};
  String filePath = '/shopping.md';
  List<Map<String, Object?>> notes = [];
  final requests = <String>[];

  String get etag => 'v$version';

  void change(String text) {
    content = text;
    version++;
  }

  Future<http.Response> handle(http.Request r) async {
    requests.add('${r.method} ${r.url.path}');
    if (offline) throw http.ClientException('offline');
    final path = r.url.path;
    if (path.contains('/apps/notes/api')) {
      return http.Response(
        jsonEncode(notes),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    if (path.endsWith('/shares')) {
      if (r.url.queryParameters['shared_with_me'] != 'true') {
        return http.Response(
          jsonEncode({
            'ocs': {
              'meta': {'statuscode': outgoingStatus},
              'data': [
                for (final id in outgoing)
                  {'item_type': 'file', 'file_source': id, 'share_type': 3},
                for (final path in outgoingFolders)
                  {'item_type': 'folder', 'file_source': 99, 'path': path},
              ],
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response(
        jsonEncode({
          'ocs': {
            'meta': {'statuscode': 200},
            'data': shared
                ? [
                    {
                      'id': '5',
                      'share_type': 0,
                      'item_type': 'file',
                      'file_source': 1480,
                      'file_target': filePath,
                      'uid_owner': 'ann',
                      'displayname_owner': 'Ann',
                      'permissions': listedPermissions ?? permissions,
                    },
                    ...otherIncoming,
                  ]
                : <Object?>[],
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    if (!path.endsWith('/shopping.md')) return http.Response('', 404);
    if (!shared) return http.Response('', 404);
    switch (r.method) {
      case 'PROPFIND':
        return http.Response(
          '<d:multistatus xmlns:d="DAV:" xmlns:oc="http://owncloud.org/ns">'
          '<d:response><d:propstat><d:prop><d:getetag>&quot;$etag&quot;'
          '</d:getetag><oc:fileid>1480</oc:fileid><oc:permissions>'
          '${permissions & 2 != 0 ? 'SGDNVW' : 'SGDNV'}</oc:permissions>'
          '</d:prop></d:propstat></d:response></d:multistatus>',
          207,
        );
      case 'GET':
        return http.Response.bytes(
          utf8.encode(content),
          200,
          headers: {'etag': '"$etag"'},
        );
      case 'PUT':
        if (r.headers['If-Match'] != '"$etag"') return http.Response('', 412);
        change(r.body);
        return http.Response('', 204, headers: {'oc-etag': '"$etag"'});
    }
    return http.Response('', 405);
  }
}

void main() {
  late NotesDatabase db;
  late FakeServer server;
  late SyncCoordinator sync;

  Future<LocalNote> shared() => (db.select(
    db.localNotes,
  )..where((n) => n.kind.equals('shared'))).getSingle();

  Future<void> edit(LocalNote note, String content) => db.saveDraft(
    accountId: 'a',
    id: note.id,
    revision: note.revision,
    title: note.title,
    content: content,
    category: note.category,
    favorite: note.favorite,
  );

  setUp(() async {
    db = NotesDatabase(NativeDatabase.memory());
    server = FakeServer();
    await db
        .into(db.accounts)
        .insert(
          AccountsCompanion.insert(
            id: 'a',
            server: 'https://cloud.test/',
            loginName: 'bob',
            credentialRef: 'secret',
          ),
        );
    final transport = MockClient(server.handle);
    final base = ServerBase.parse('https://cloud.test');
    sync = SyncCoordinator(
      db,
      (_) async => NotesClient(
        base: base,
        transport: transport,
        loginName: 'bob',
        appPassword: 'secret',
      ),
      sharingFor: (_) async => SharingClient(
        base: base,
        transport: transport,
        loginName: 'bob',
        appPassword: 'secret',
      ),
      shareListInterval: Duration.zero,
    );
  });
  tearDown(() => db.close());

  test(
    'a moved DAV file uses its new path for inherited outgoing shares',
    () async {
      await sync.sync('a');
      server.outgoingFolders.add('/Team');
      server.filePath = '/Team/shopping.md';
      await sync.sync('a');
      expect((await shared()).davPath, '/Team/shopping.md');
      expect((await shared()).sharedByMe, isTrue);
      server.filePath = '/Other/shopping.md';
      await sync.sync('a');
      expect((await shared()).sharedByMe, isFalse);
    },
  );

  test(
    'a writable group share keeps an edited file writable beside a view-only share',
    () async {
      await sync.sync('a');
      final note = await shared();
      await edit(note, 'local edit through group');
      server.listedPermissions = 1;
      server.otherIncoming = [
        {
          'id': 'group',
          'share_type': 1,
          'item_type': 'file',
          'file_source': 1480,
          'file_target': '/shopping.md',
          'uid_owner': 'ann',
          'permissions': 3,
        },
      ];
      await sync.sync('a');
      final rows = await db.select(db.localNotes).get();
      expect(rows, hasLength(1));
      expect(rows.single.readonly, isFalse);
      expect(rows.single.syncState, 'clean');
      expect(server.content, 'local edit through group');
    },
  );

  test('an incoming share becomes a shared note', () async {
    await sync.sync('a');
    final note = await shared();
    expect(note.title, 'shopping');
    expect(note.content, server.content);
    expect(note.remoteId, 1480);
    expect(note.davPath, '/shopping.md');
    expect(note.etag, 'v1');
    expect(note.syncState, 'clean');
    expect(note.readonly, isFalse);
  });

  test('an edit is sent with If-Match and acknowledged', () async {
    await sync.sync('a');
    var note = await shared();
    await edit(note, 'milk\nbread\neggs\nbutter\n');
    await sync.sync('a');
    note = await shared();
    expect(server.content, 'milk\nbread\neggs\nbutter\n');
    expect(note.syncState, 'clean');
    expect(note.etag, server.etag);
    expect(note.baseContent, server.content);
    final ops = await db.select(db.operations).get();
    expect(ops.single.state, 'done');
  });

  test('the open note takes the other side\'s edit on the next pass', () async {
    await sync.sync('a');
    final before = await shared();
    server.change('milk\nbread\neggs\ncoffee\n');
    await sync.sync('a');
    final note = await shared();
    expect(note.content, 'milk\nbread\neggs\ncoffee\n');
    expect(note.revision, before.revision + 1);
    expect(note.syncState, 'clean');
  });

  test('an unchanged file costs one PROPFIND and no download', () async {
    await sync.sync('a');
    server.requests.clear();
    await sync.sync('a');
    expect(server.requests.where((r) => r.startsWith('GET /remote')), isEmpty);
    expect(
      server.requests.where((r) => r.startsWith('PROPFIND')),
      hasLength(1),
    );
  });

  test('edits on different lines merge after a rejected If-Match', () async {
    await sync.sync('a');
    final note = await shared();
    await edit(note, 'oat milk\nbread\neggs\n');
    server.change('milk\nbread\neggs\nbutter\n');
    await sync.sync('a');
    expect(server.content, 'oat milk\nbread\neggs\nbutter\n');
    final merged = await shared();
    expect(merged.content, server.content);
    expect(merged.syncState, 'clean');
  });

  test('the same line changed on both sides asks for a decision', () async {
    await sync.sync('a');
    final note = await shared();
    await edit(note, 'oat milk\nbread\neggs\n');
    server.change('soy milk\nbread\neggs\n');
    await sync.sync('a');
    final stuck = await shared();
    expect(stuck.syncState, 'needsDecision');
    expect(stuck.content, 'oat milk\nbread\neggs\n');
    expect(server.content, 'soy milk\nbread\neggs\n');
    final op = (await db.select(db.operations).get()).single;
    expect(op.errorCode, 'remote_conflict');

    final remote = await sync.readShared(stuck);
    expect(remote.content, server.content);
    await NoteRecovery(db).useRemote(
      expected: stuck,
      remote: remote,
      keepLocal: true,
      content: mergeVersions(stuck.content, remote.content),
    );
    await sync.sync('a');
    final resolved = await shared();
    expect(resolved.syncState, 'clean');
    expect(server.content, resolved.content);
    expect(server.content, contains('oat milk'));
    expect(server.content, contains('soy milk'));
  });

  test('offline edits stay drafts and nothing is half sent', () async {
    await sync.sync('a');
    final note = await shared();
    await edit(note, 'tea\n');
    server.offline = true;
    await expectLater(sync.sync('a'), throwsA(anything));
    expect((await shared()).syncState, 'draft');
    expect(await db.select(db.operations).get(), isEmpty);
    server.offline = false;
    await sync.sync('a');
    expect(server.content, 'tea\n');
  });

  test('a write that failed but landed is recognised', () async {
    await sync.sync('a');
    final note = await shared();
    await edit(note, 'tea\n');
    // The server applies the PUT, then the answer is lost.
    final lost = MockClient((r) async {
      final response = await server.handle(r);
      if (r.method == 'PUT') throw http.ClientException('reset');
      return response;
    });
    final base = ServerBase.parse('https://cloud.test');
    final flaky = SyncCoordinator(
      db,
      (_) async => NotesClient(
        base: base,
        transport: lost,
        loginName: 'bob',
        appPassword: 'secret',
      ),
      sharingFor: (_) async => SharingClient(
        base: base,
        transport: lost,
        loginName: 'bob',
        appPassword: 'secret',
      ),
      shareListInterval: Duration.zero,
    );
    await flaky.sync('a');
    expect(server.content, 'tea\n');
    expect((await shared()).syncState, 'clean');
  });

  test('a read-only share cannot send', () async {
    server.permissions = 1;
    await sync.sync('a');
    final note = await shared();
    expect(note.readonly, isTrue);
    expect(edit(note, 'x'), throwsA(isA<StateError>()));
  });

  test('an ended share removes a clean note but keeps local edits', () async {
    await sync.sync('a');
    server.shared = false;
    await sync.sync('a');
    expect(await db.select(db.localNotes).get(), isEmpty);

    server.shared = true;
    await sync.sync('a');
    await edit(await shared(), 'mine\n');
    server.shared = false;
    await sync.sync('a');
    final kept = await shared();
    expect(kept.content, 'mine\n');
    expect(kept.syncState, 'draft');
  });

  test('a shared note cannot be deleted locally', () async {
    await sync.sync('a');
    final note = await shared();
    expect(db.markDeleted('a', note.id), throwsA(isA<StateError>()));
  });

  test(
    'the Notes API listing the file turns it into an ordinary note',
    () async {
      await sync.sync('a');
      server.notes = [
        {
          'id': 1480,
          'etag': 'notes-etag',
          'title': 'shopping',
          'content': server.content,
          'category': '',
          'favorite': false,
          'readonly': false,
          'modified': 100,
        },
      ];
      await sync.sync('a');
      final rows = await db.select(db.localNotes).get();
      expect(rows, hasLength(1));
      expect(rows.single.kind, 'note');
      expect(rows.single.sharedWithMe, isTrue);
      expect(rows.single.sharedByMe, isFalse);
      expect(rows.single.davPath, isNull);
      expect(rows.single.etag, 'notes-etag');
      final before = rows.single;
      server.outgoing.add(1480);
      await sync.sync('a');
      expect((await db.note('a', before.id))!.sharedByMe, isTrue);
      server.shared = false;
      server.outgoingStatus = 503;
      await sync.sync('a');
      final partial = (await db.note('a', before.id))!;
      expect(partial.sharedWithMe, isFalse);
      expect(partial.sharedByMe, isTrue);
      expect(partial.content, before.content);
      expect(partial.kind, 'note');
      server.outgoingStatus = 200;
      server.outgoing.clear();
      await sync.sync('a');
      expect((await db.note('a', before.id))!.sharedByMe, isFalse);
    },
  );

  test('a schema 4 draft survives the sharing-metadata upgrade', () async {
    final dir = await Directory.systemTemp.createTemp('ownnotes-v4-');
    final file = File('${dir.path}/notes.sqlite');
    final old = NotesDatabase(NativeDatabase(file));
    await old
        .into(old.accounts)
        .insert(
          AccountsCompanion.insert(
            id: 'legacy',
            server: 'https://cloud.test/',
            loginName: 'test',
            credentialRef: 'ref',
          ),
        );
    final id = await old.createDraft('legacy', content: 'unsent text');
    await old.customStatement(
      'ALTER TABLE local_notes DROP COLUMN shared_with_me',
    );
    await old.customStatement(
      'ALTER TABLE local_notes DROP COLUMN shared_by_me',
    );
    await old.customStatement('DROP TABLE pull_checkpoints');
    await old.customStatement(
      'ALTER TABLE local_notes DROP COLUMN remote_path',
    );
    await old.customStatement('PRAGMA user_version = 4');
    await old.close();
    final upgraded = NotesDatabase(NativeDatabase(file));
    try {
      final note = (await upgraded.note('legacy', id))!;
      expect(note.content, 'unsent text');
      expect(note.syncState, 'draft');
      expect(note.sharedWithMe, isNull);
      expect(note.sharedByMe, isNull);
      expect(upgraded.schemaVersion, 8);
    } finally {
      await upgraded.close();
      await dir.delete(recursive: true);
    }
  });

  test('a database from schema 2 gains the shared columns', () async {
    final dir = await Directory.systemTemp.createTemp('ownnotes-schema-');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/notes.sqlite');
    final first = NotesDatabase(NativeDatabase(file));
    await first.customStatement('ALTER TABLE local_notes DROP COLUMN kind');
    await first.customStatement('ALTER TABLE local_notes DROP COLUMN dav_path');
    await first.customStatement('DROP TABLE sync_statuses');
    await first.customStatement('DROP TABLE recovery_copies');
    for (final c in ['delete_error', 'unreadable', 'missing_since']) {
      await first.customStatement('ALTER TABLE local_notes DROP COLUMN $c');
    }
    await first.customStatement(
      'ALTER TABLE local_notes DROP COLUMN shared_with_me',
    );
    await first.customStatement(
      'ALTER TABLE local_notes DROP COLUMN shared_by_me',
    );
    await first.customStatement('DROP TABLE pull_checkpoints');
    await first.customStatement(
      'ALTER TABLE local_notes DROP COLUMN remote_path',
    );
    await first.customStatement('PRAGMA user_version = 2');
    await first.close();
    final upgraded = NotesDatabase(NativeDatabase(file));
    addTearDown(upgraded.close);
    expect(await upgraded.select(upgraded.localNotes).get(), isEmpty);
    await upgraded
        .into(upgraded.accounts)
        .insert(
          AccountsCompanion.insert(
            id: 'a',
            server: 's',
            loginName: 'u',
            credentialRef: 'c',
          ),
        );
    final id = await upgraded.createDraft('a');
    expect((await upgraded.note('a', id))!.kind, 'note');
  });
}
