import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:notes_protocol/notes_protocol.dart';
import 'package:notes_store/notes_store.dart';
import 'package:test/test.dart';

class FolderServer {
  String mount = '/Shared';
  bool direct = true, folder = true, failNested = false, pruned = false;
  final removed = <int>{};
  final content = <int, String>{
    41: 'Root text',
    42: 'Nested text',
    43: 'Plain text',
  };
  final writable = <int, bool>{41: false, 42: true, 43: false};
  final versions = <int, int>{41: 1, 42: 1, 43: 1};
  final requests = <String>[];
  final noteQueries = <Map<String, String>>[];
  Future<void> Function()? beforeNotes;

  Set<int> get noteIds => {
    if (direct && !removed.contains(41)) 41,
    if (folder && mount.startsWith('/Notes/'))
      ...content.keys.where((id) => !removed.contains(id)),
  };
  String path(int id) =>
      '$mount/${switch (id) {
        41 => 'Root.md',
        42 => 'Sub/Nested.md',
        _ => 'Sub/Plain.txt',
      }}';
  String notePath(int id) => id == 41 && direct ? '/Notes/Direct.md' : path(id);
  String etag(int id) => 'dav-$id-${versions[id]}';
  Map<String, Object> note(int id) => {
    'id': id,
    'etag': 'rest-$id-${versions[id]}',
    'title': 'Note $id',
    'content': content[id]!,
    'category': '',
    'favorite': false,
    'readonly': !(id == 41 && direct || writable[id]!),
    'modified': 100,
    'internalPath': notePath(id),
  };
  http.Response json(Object data) => http.Response(
    jsonEncode(data),
    200,
    headers: {
      'content-type': 'application/json',
      'last-modified': HttpDate.format(
        DateTime.fromMillisecondsSinceEpoch(500000, isUtc: true),
      ),
    },
  );
  String entry(
    String path,
    int id, {
    bool folder = false,
    bool write = false,
  }) =>
      '<d:response><d:href>/remote.php/dav/files/user${Uri(pathSegments: path.split('/'))}</d:href>'
      '<d:propstat><d:prop><d:resourcetype>${folder ? '<d:collection/>' : ''}</d:resourcetype>'
      '<oc:fileid>$id</oc:fileid><oc:permissions>G${write ? 'W' : ''}</oc:permissions>'
      '<d:getetag>&quot;${folder ? 'folder-$id' : etag(id)}&quot;</d:getetag>'
      '</d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>';
  http.Response listing(List<String> entries) => http.Response(
    '<d:multistatus xmlns:d="DAV:" xmlns:oc="http://owncloud.org/ns">${entries.join()}</d:multistatus>',
    207,
  );

  Future<http.Response> handle(http.Request request) async {
    requests.add('${request.method} ${request.url.path}');
    final url = request.url;
    if (url.path.contains('/apps/notes/api/')) {
      if (url.path.endsWith('/notes')) {
        noteQueries.add(Map.of(url.queryParameters));
        final hook = beforeNotes;
        beforeNotes = null;
        await hook?.call();
        return json([
          for (final id in noteIds)
            if (pruned && url.queryParameters.containsKey('pruneBefore'))
              {'id': id}
            else
              note(id),
        ]);
      }
      final id = int.parse(url.pathSegments.last);
      if (!noteIds.contains(id)) return http.Response('', 404);
      expect(request.method, 'GET', reason: 'unexpected REST mutation');
      return json(note(id));
    }
    if (url.path.endsWith('/shares')) {
      final incoming = url.queryParameters['shared_with_me'] == 'true';
      return json({
        'ocs': {
          'meta': {'statuscode': 100},
          'data': [
            if (incoming && folder)
              {
                'id': 'folder',
                'item_type': 'folder',
                'share_type': 0,
                'file_source': 40,
                'file_target': mount,
                'permissions': 31,
                'uid_owner': 'owner',
              },
            if (incoming && direct)
              {
                'id': 'direct',
                'item_type': 'file',
                'share_type': 0,
                'file_source': 41,
                'file_target': '/Notes/Direct.md',
                'permissions': 3,
                'uid_owner': 'owner',
              },
          ],
        },
      });
    }
    final path = url.path.replaceFirst('/remote.php/dav/files/user', '');
    if (request.method == 'PROPFIND' && request.headers['Depth'] == '1') {
      if (path == mount) {
        return listing([
          entry(mount, 40, folder: true),
          if (!removed.contains(41))
            entry(this.path(41), 41, write: writable[41]!),
          entry('$mount/Sub', 44, folder: true),
        ]);
      }
      if (path == '$mount/Sub') {
        if (failNested) return http.Response('', 503);
        return listing([
          entry(path, 44, folder: true),
          for (final id in [42, 43])
            if (!removed.contains(id))
              entry(this.path(id), id, write: writable[id]!),
        ]);
      }
      return http.Response('', 404);
    }
    final id = path == '/Notes/Direct.md' && direct
        ? 41
        : content.keys.where((id) => this.path(id) == path).firstOrNull;
    if (id == null ||
        removed.contains(id) ||
        (!folder && path != '/Notes/Direct.md')) {
      return http.Response('', 404);
    }
    final editable = path == '/Notes/Direct.md' && direct || writable[id]!;
    if (request.method == 'PROPFIND') {
      return listing([entry(path, id, write: editable)]);
    }
    if (request.method == 'GET') {
      return http.Response(
        content[id]!,
        200,
        headers: {'etag': '"${etag(id)}"'},
      );
    }
    if (request.method == 'PUT') {
      if (!editable) return http.Response('', 403);
      if (request.headers['If-Match'] != '"${etag(id)}"') {
        return http.Response('', 412);
      }
      content[id] = request.body;
      versions[id] = versions[id]! + 1;
      return http.Response('', 204, headers: {'oc-etag': '"${etag(id)}"'});
    }
    return http.Response('', 405);
  }
}

void main() {
  late NotesDatabase db;
  late FolderServer server;
  late SyncCoordinator sync;
  setUp(() async {
    db = NotesDatabase(NativeDatabase.memory());
    server = FolderServer();
    await db
        .into(db.accounts)
        .insert(
          AccountsCompanion.insert(
            id: 'a',
            server: 'https://cloud.test/',
            loginName: 'user',
            credentialRef: 'ref',
          ),
        );
    final transport = MockClient(server.handle);
    final base = ServerBase.parse('https://cloud.test/');
    sync = SyncCoordinator(
      db,
      (_) async => NotesClient(
        base: base,
        transport: transport,
        loginName: 'user',
        appPassword: 'secret',
      ),
      sharingFor: (_) async => SharingClient(
        base: base,
        transport: transport,
        loginName: 'user',
        appPassword: 'secret',
      ),
    );
  });
  tearDown(() => db.close());
  Future<LocalNote> row(int id) => (db.select(
    db.localNotes,
  )..where((n) => n.remoteId.equals(id))).getSingle();

  test(
    'nested Markdown and text files are discovered while direct Notes IDs stay singular',
    () async {
      await sync.sync('a');
      expect(await db.select(db.localNotes).get(), hasLength(3));
      expect((await row(41)).kind, 'note');
      expect((await row(42)).kind, 'shared');
      expect((await row(42)).readonly, isFalse);
      expect((await row(43)).readonly, isTrue);
      expect((await row(43)).content, 'Plain text');
      expect(
        server.requests.where(
          (r) => r.startsWith('GET /remote') && r.endsWith('/Root.md'),
        ),
        isEmpty,
      );
    },
  );

  test(
    'removing a direct share changes Notes to DAV without replacing its local identity',
    () async {
      await sync.sync('a');
      final before = await row(41);
      server.direct = false;
      await sync.sync('a');
      final after = await row(41);
      expect(after.id, before.id);
      expect(after.kind, 'shared');
      expect(after.davPath, '/Shared/Root.md');
      expect(after.etag, server.etag(41));
      expect(after.content, before.content);
      expect(after.readonly, isTrue);
      expect(await db.select(db.recoveryCopies).get(), isEmpty);
    },
  );

  test(
    'a mount can move into Notes and back, even when the first REST listing is pruned',
    () async {
      server.direct = false;
      await sync.sync('a');
      final before = await row(42);
      server.mount = '/Notes/Shared';
      server.pruned = true;
      server.noteQueries.clear();
      await sync.sync('a');
      expect(server.noteQueries.first, contains('pruneBefore'));
      expect(server.noteQueries.last, isNot(contains('pruneBefore')));
      expect((await row(42)).id, before.id);
      expect((await row(42)).kind, 'note');
      expect((await row(42)).etag, 'rest-42-1');
      server.mount = '/Moved';
      await sync.sync('a');
      expect((await row(42)).id, before.id);
      expect((await row(42)).kind, 'shared');
      expect((await row(42)).davPath, '/Moved/Sub/Nested.md');
      expect(await db.select(db.localNotes).get(), hasLength(3));
    },
  );

  test(
    'a partial folder traversal preserves the Notes row that is awaiting a route change',
    () async {
      await sync.sync('a');
      final before = await row(41);
      server.direct = false;
      server.failNested = true;
      await expectLater(sync.sync('a'), throwsA(isA<NotesHttpException>()));
      expect(await row(41), before);
      expect(await db.select(db.localNotes).get(), hasLength(3));
      expect(await db.select(db.recoveryCopies).get(), isEmpty);
      server.failNested = false;
      await sync.sync('a');
      expect((await row(41)).id, before.id);
      expect((await row(41)).kind, 'shared');
    },
  );

  test(
    'renaming a mount keeps a dirty DAV note and writes through the new path',
    () async {
      await sync.sync('a');
      final before = await row(42);
      await db.saveDraft(
        accountId: 'a',
        id: before.id,
        revision: before.revision,
        title: before.title,
        content: 'Local edit',
        category: before.category,
        favorite: false,
      );
      server.mount = '/Moved';
      await sync.sync('a', relist: true);
      final after = await row(42);
      expect(after.id, before.id);
      expect(after.content, 'Local edit');
      expect(after.syncState, 'clean');
      expect(
        server.requests,
        contains('PUT /remote.php/dav/files/user/Moved/Sub/Nested.md'),
      );
    },
  );

  test(
    'dirty route changes preserve text and never send a foreign ETag',
    () async {
      await sync.sync('a');
      final before = await row(41);
      await db.saveDraft(
        accountId: 'a',
        id: before.id,
        revision: before.revision,
        title: before.title,
        content: 'Local pending text',
        category: before.category,
        favorite: false,
      );
      server.direct = false;
      await sync.sync('a');
      final after = await row(41);
      expect(after.id, before.id);
      expect(after.kind, 'shared');
      expect(after.content, 'Local pending text');
      expect(after.etag, isNull);
      expect(after.syncState, 'needsDecision');
      expect(
        server.requests.where((r) => r.startsWith('PUT /remote')),
        isEmpty,
      );
      expect(await db.select(db.operations).get(), isNotEmpty);
      server.mount = '/Notes/Shared';
      await sync.sync('a', relist: true);
      final back = await row(41);
      expect(back.kind, 'note');
      expect(back.id, before.id);
      expect(back.content, 'Local pending text');
      expect(back.etag, isNull);
      expect(back.syncState, 'needsDecision');
    },
  );

  test(
    'removing a folder preserves dirty notes and recovery copies of clean notes',
    () async {
      server.direct = false;
      await sync.sync('a');
      final dirty = await row(42);
      await db.saveDraft(
        accountId: 'a',
        id: dirty.id,
        revision: dirty.revision,
        title: dirty.title,
        content: 'Unsent text',
        category: dirty.category,
        favorite: false,
      );
      server.folder = false;
      await sync.sync('a', relist: true);
      expect((await row(42)).content, 'Unsent text');
      expect((await row(42)).syncState, 'draft');
      expect(await db.select(db.localNotes).get(), hasLength(1));
      expect(await db.select(db.recoveryCopies).get(), hasLength(2));
    },
  );

  test('a stale Notes pull cannot convert or remove existing rows', () async {
    await sync.sync('a');
    final before = await row(41);
    server.direct = false;
    server.beforeNotes = () async {
      await db
          .update(db.accounts)
          .write(const AccountsCompanion(mutationEpoch: Value(1)));
    };
    server.requests.clear();
    await sync.sync('a');
    expect(await row(41), before);
    expect(server.requests.any((r) => r.startsWith('PROPFIND')), isFalse);
  });
}
