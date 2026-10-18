import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:notes_protocol/notes_protocol.dart';
import 'package:notes_store/notes_store.dart';
import 'package:test/test.dart';

void main() {
  late NotesDatabase db;
  late LocalNote note;
  final remote = RemoteNote(
    id: 7,
    etag: 'fresh',
    title: 'Remote',
    content: 'server',
    category: '',
    favorite: false,
    readonly: false,
    modified: 1,
  );
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
    final id = await db.createDraft('a');
    await (db.update(db.localNotes)..where((n) => n.id.equals(id))).write(
      const LocalNotesCompanion(
        content: Value('local'),
        remoteId: Value(7),
        syncState: Value('needsDecision'),
      ),
    );
    note = (await db.note('a', id))!;
  });
  tearDown(() => db.close());
  test(
    'explicit keep local rebases against inspected ETag and fences reads',
    () async {
      await NoteRecovery(
        db,
      ).useRemote(expected: note, remote: remote, keepLocal: true);
      final result = (await db.note('a', note.id))!;
      expect(result.content, 'local');
      expect(result.baseContent, 'server');
      expect(result.etag, 'fresh');
      expect(result.syncState, 'draft');
      expect(await db.readEpoch('a'), 1);
    },
  );
  test('stale decision cannot discard newer draft', () async {
    await db.saveDraft(
      accountId: 'a',
      id: note.id,
      revision: note.revision,
      title: '',
      content: 'newer',
      category: '',
      favorite: false,
    );
    await expectLater(
      NoteRecovery(
        db,
      ).useRemote(expected: note, remote: remote, keepLocal: false),
      throwsStateError,
    );
    expect((await db.note('a', note.id))!.content, 'newer');
  });
  test(
    'new copy preserves original recovery evidence and resets remote identity',
    () async {
      final id = await NoteRecovery(db).copyAsNew(note);
      expect((await db.note('a', note.id))!.syncState, 'recoveryArchived');
      final copy = (await db.note('a', id))!;
      expect(copy.content, 'local');
      expect(copy.remoteId, isNull);
      expect(copy.etag, isNull);
      expect(copy.syncState, 'draft');
      expect((await db.watchNotes('a').first).map((n) => n.id), [id]);
      await expectLater(NoteRecovery(db).copyAsNew(note), throwsStateError);
    },
  );
}
