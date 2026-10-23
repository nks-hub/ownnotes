import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:notes_protocol/notes_protocol.dart';
import 'package:notes_store/notes_store.dart';
import 'package:notes_store/src/pull_checkpoint.dart';
import 'package:test/test.dart';

Future<void> account(NotesDatabase db, String id) async {
  await db
      .into(db.accounts)
      .insert(
        AccountsCompanion.insert(
          id: id,
          server: 'https://cloud.test/',
          loginName: id,
          credentialRef: 'ref-$id',
        ),
      );
}

Future<String> legacyArchive(NotesDatabase db, String accountId) async {
  final id = await db.createDraft(accountId, content: '# Preserved local text');
  await (db.update(db.localNotes)..where((n) => n.id.equals(id))).write(
    const LocalNotesCompanion(
      remoteId: Value(41),
      etag: Value('old'),
      syncState: Value('recoveryArchived'),
      baseContent: Value('old server text'),
    ),
  );
  return id;
}

void main() {
  for (final version in [5, 6]) {
    test(
      'schema $version detaches old archives without changing recovery evidence',
      () async {
        final dir = await Directory.systemTemp.createTemp('ownnotes-archive-');
        addTearDown(() => dir.delete(recursive: true));
        final file = File('${dir.path}/notes.sqlite');
        final old = NotesDatabase(NativeDatabase(file));
        await account(old, 'a');
        await account(old, 'b');
        final archivedId = await legacyArchive(old, 'a');
        final otherArchiveId = await legacyArchive(old, 'b');
        final pendingId = await old.createDraft(
          'a',
          content: 'Pending decision',
        );
        await (old.update(
          old.localNotes,
        )..where((n) => n.id.equals(pendingId))).write(
          const LocalNotesCompanion(
            remoteId: Value(42),
            etag: Value('pending'),
            syncState: Value('needsDecision'),
          ),
        );
        final pending = (await old.note('a', pendingId))!;
        final archived = (await old.note('a', archivedId))!;
        await old.keepCopy(archived, 'conflict', reason: 'uncertain_write');
        await old
            .into(old.operations)
            .insert(
              OperationsCompanion.insert(
                id: 'operation',
                accountId: 'a',
                noteId: archivedId,
                revision: archived.revision,
                kind: 'update',
                state: const Value('dismissed'),
                payload: '{"content":"Preserved intent"}',
              ),
            );
        final operation = await old.select(old.operations).getSingle();
        final recovery = await old.select(old.recoveryCopies).getSingle();
        if (version == 5) {
          await old.customStatement('DROP TABLE pull_checkpoints');
        }
        await old.customStatement(
          'ALTER TABLE local_notes DROP COLUMN remote_path',
        );
        await old.customStatement('PRAGMA user_version = $version');
        await old.close();

        final upgraded = NotesDatabase(NativeDatabase(file));
        try {
          final after = (await upgraded.note('a', archivedId))!;
          expect(after.remoteId, isNull);
          expect(after.etag, isNull);
          expect({
            ...after.toJson(),
            'remoteId': archived.remoteId,
            'etag': archived.etag,
          }, archived.toJson());
          expect((await upgraded.note('b', otherArchiveId))!.remoteId, isNull);
          expect(
            (await upgraded.note('b', otherArchiveId))!.content,
            '# Preserved local text',
          );
          expect(await upgraded.note('a', pendingId), pending);
          expect(
            await upgraded.select(upgraded.operations).getSingle(),
            operation,
          );
          expect(
            await upgraded.select(upgraded.recoveryCopies).getSingle(),
            recovery,
          );
          expect(
            await upgraded.customSelect('PRAGMA foreign_key_check').get(),
            isEmpty,
          );
          expect((await upgraded.watchNotes('a').first).map((n) => n.id), [
            pendingId,
          ]);
        } finally {
          await upgraded.close();
        }
        final reopened = NotesDatabase(NativeDatabase(file));
        try {
          expect(
            (await reopened.note('a', archivedId))!.content,
            archived.content,
          );
          expect((await reopened.note('a', archivedId))!.remoteId, isNull);
          expect(
            await reopened.select(reopened.operations).getSingle(),
            operation,
          );
        } finally {
          await reopened.close();
        }
      },
    );
  }

  test(
    'a detached archive cannot validate a pruned server note after upgrade',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'ownnotes-archive-sync-',
      );
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/notes.sqlite');
      final old = NotesDatabase(NativeDatabase(file));
      await account(old, 'a');
      final archivedId = await legacyArchive(old, 'a');
      await old
          .into(old.pullCheckpoints)
          .insert(
            PullCheckpointsCompanion.insert(
              accountId: 'a',
              epoch: 0,
              generation: 1,
              watermark: 100,
              listEtag: const Value('"stale"'),
              etagPruneBefore: const Value(90),
              remoteIds: '[41]',
            ),
          );
      await old.customStatement(
        'ALTER TABLE local_notes DROP COLUMN remote_path',
      );
      await old.customStatement('PRAGMA user_version = 6');
      await old.close();

      final db = NotesDatabase(NativeDatabase(file));
      var calls = 0;
      final transport = MockClient((request) async {
        expect(request.method, 'GET');
        if (++calls == 1) {
          expect(request.headers['If-None-Match'], isNull);
          return http.Response(
            '[{"id":41}]',
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        expect(request.url.queryParameters, {'chunkSize': '100'});
        return http.Response(
          jsonEncode([
            {
              'id': 41,
              'etag': 'new',
              'title': 'Server version',
              'content': 'Current server text',
              'category': '',
              'favorite': false,
              'readonly': false,
              'modified': 100,
            },
          ]),
          200,
          headers: {
            'content-type': 'application/json',
            'last-modified': HttpDate.format(
              DateTime.fromMillisecondsSinceEpoch(200000, isUtc: true),
            ),
          },
        );
      });
      try {
        final sync = SyncCoordinator(
          db,
          (_) async => NotesClient(
            base: ServerBase.parse('https://cloud.test/'),
            transport: transport,
            loginName: 'user',
            appPassword: 'secret',
          ),
        );
        await sync.sync('a');
        expect(calls, 2);
        final visible = (await db.watchNotes('a').first).single;
        expect(visible.id, isNot(archivedId));
        expect(visible.remoteId, 41);
        expect(visible.content, 'Current server text');
        expect(
          (await db.note('a', archivedId))!.content,
          '# Preserved local text',
        );
        expect((await db.note('a', archivedId))!.syncState, 'recoveryArchived');
        expect((await db.pullCheckpoint('a'))!.watermark, 200);
      } finally {
        transport.close();
        await db.close();
      }
    },
  );
}
