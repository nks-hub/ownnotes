import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:notes_protocol/notes_protocol.dart';
import 'package:notes_store/notes_store.dart';
import 'package:test/test.dart';

http.Response json(Object value) => http.Response(
  jsonEncode(value),
  200,
  headers: {'content-type': 'application/json'},
);

void main() {
  test(
    'schema 7 upgrade clears the pruned baseline and preserves local text',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'ownnotes-path-migration-',
      );
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/notes.sqlite');
      final old = NotesDatabase(NativeDatabase(file));
      await old
          .into(old.accounts)
          .insert(
            AccountsCompanion.insert(
              id: 'a',
              server: 'https://cloud.test/',
              loginName: 'user',
              credentialRef: 'ref',
            ),
          );
      final draftId = await old.createDraft('a', content: 'Unsent local text');
      await old.applyPull('a', 0, [
        const RemoteNote(
          id: 42,
          etag: 'a',
          title: 'Plan',
          content: 'Server text',
          category: 'Team',
          favorite: false,
          readonly: false,
          modified: 10,
        ),
      ]);
      await old
          .into(old.pullCheckpoints)
          .insert(
            PullCheckpointsCompanion.insert(
              accountId: 'a',
              epoch: 0,
              generation: 1,
              watermark: 100,
              listEtag: const Value('"old"'),
              remoteIds: '[42]',
            ),
          );
      await old.customStatement(
        'ALTER TABLE local_notes DROP COLUMN remote_path',
      );
      await old.customStatement('PRAGMA user_version = 7');
      await old.close();
      final db = NotesDatabase(NativeDatabase(file));
      try {
        expect((await db.note('a', draftId))!.content, 'Unsent local text');
        expect((await db.note('a', draftId))!.syncState, 'draft');
        expect(await db.select(db.pullCheckpoints).get(), isEmpty);
        await db.applyPull('a', 0, [
          const RemoteNote(
            id: 42,
            etag: 'a',
            title: 'Plan',
            content: 'Server text',
            category: 'Team',
            favorite: false,
            readonly: false,
            modified: 10,
            internalPath: '/Notes/Team/Plan.md',
          ),
        ]);
        final note = await (db.select(
          db.localNotes,
        )..where((n) => n.remoteId.equals(42))).getSingle();
        expect(note.remotePath, '/Notes/Team/Plan.md');
        expect((await db.note('a', draftId))!.content, 'Unsent local text');
      } finally {
        await db.close();
      }
    },
  );

  test(
    'a create receipt retains its path even when the following pull sends IDs only',
    () async {
      final db = NotesDatabase(NativeDatabase.memory());
      addTearDown(db.close);
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
      final id = await db.createDraft(
        'a',
        content: 'New note',
        category: 'Team',
      );
      var created = false;
      final transport = MockClient((request) async {
        if (request.url.path.endsWith('/shares')) {
          return json({
            'ocs': {
              'meta': {'statuscode': 100},
              'data': [
                if (!request.url.queryParameters.containsKey('shared_with_me'))
                  {
                    'item_type': 'folder',
                    'path': '/Notes/Team',
                    'file_source': 40,
                  },
              ],
            },
          });
        }
        if (request.method == 'POST') {
          created = true;
          return json({
            'id': 42,
            'title': 'New note',
            'content': 'New note',
            'category': 'Team',
            'favorite': false,
            'readonly': false,
            'modified': 10,
            'etag': 'a',
            'internalPath': '/Notes/Team/New note.md',
          });
        }
        return json([
          if (created) {'id': 42},
        ]);
      });
      addTearDown(transport.close);
      final base = ServerBase.parse('https://cloud.test/');
      final sync = SyncCoordinator(
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
      await sync.sync('a');
      final note = (await db.note('a', id))!;
      expect(note.remotePath, '/Notes/Team/New note.md');
      expect(note.sharedByMe, isTrue);
      expect(note.syncState, 'clean');
    },
  );

  for (final received in [true, false]) {
    test('folder sharing marks a Notes API note: incoming=$received', () async {
      final db = NotesDatabase(NativeDatabase.memory());
      addTearDown(db.close);
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
      var shared = true;
      var readonly = received;
      String? path = '/Notes/Team/Plan.md';
      final transport = MockClient((request) async {
        expect(request.method, 'GET');
        if (request.url.path.endsWith('/notes')) {
          return json([
            {
              'id': 42,
              'title': 'Plan',
              'content': 'Keep this text',
              'etag': 'a',
              'category': 'Team',
              'favorite': false,
              'modified': 10,
              'internalPath': ?path,
              'readonly': readonly,
              'isShared': false,
            },
          ]);
        }
        expect(request.url.path.endsWith('/shares'), isTrue);
        final incoming =
            request.url.queryParameters['shared_with_me'] == 'true';
        return json({
          'ocs': {
            'meta': {'statuscode': 100},
            'data': [
              if (shared && incoming == received)
                {
                  'id': '5',
                  'item_type': 'folder',
                  'file_source': 40,
                  'file_target': '/Notes/Team',
                  'path': '/Notes/Team',
                  'uid_owner': 'owner',
                  'share_with': 'user',
                  'share_type': 0,
                  'permissions': readonly ? 1 : 3,
                },
            ],
          },
        });
      });
      addTearDown(transport.close);
      final base = ServerBase.parse('https://cloud.test/');
      final sync = SyncCoordinator(
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
      await sync.sync('a');
      final first = await db.select(db.localNotes).getSingle();
      expect(first.kind, 'note');
      expect(first.sharedWithMe, received);
      expect(first.sharedByMe, !received);
      expect(first.readonly, readonly);
      expect(first.content, 'Keep this text');
      readonly = false;
      await sync.sync('a', relist: true);
      expect((await db.note('a', first.id))!.readonly, isFalse);
      expect((await db.note('a', first.id))!.sharedWithMe, received);
      path = null;
      await sync.sync('a', relist: true);
      expect((await db.note('a', first.id))!.sharedWithMe, received);
      expect((await db.note('a', first.id))!.sharedByMe, !received);
      path = '/Notes/Team 2/Plan.md';
      await sync.sync('a', relist: true);
      expect((await db.note('a', first.id))!.sharedWithMe, isFalse);
      expect((await db.note('a', first.id))!.sharedByMe, isFalse);
      path = '/Notes/Team/Plan.md';
      await sync.sync('a', relist: true);
      shared = false;
      await sync.sync('a', relist: true);
      final last = (await db.note('a', first.id))!;
      expect(last.sharedWithMe, isFalse);
      expect(last.sharedByMe, isFalse);
      expect(last.content, first.content);
      expect(last.kind, 'note');
    });
  }
}
