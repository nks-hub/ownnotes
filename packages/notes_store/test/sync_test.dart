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
      await (db.delete(db.accounts)..where((a) => a.id.equals('a'))).go();
      return response(remote(17));
    });
    await sync.sync('a');
    expect(await db.select(db.localNotes).get(), isEmpty);
    expect(await db.select(db.operations).get(), isEmpty);
  });
}
