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
  test('merged versions keep the lines of both phones', () async {
    expect(
      mergeVersions(
        'List\n\nmilk\nbread\nS9 line\n',
        'List\n\nmilk\nbread\nEMU line\n',
      ),
      'List\n\nmilk\nbread\nS9 line\nEMU line\n',
    );
    expect(mergeVersions('a\nb\nc', 'a\nX\nc'), 'a\nb\nX\nc');
    // Seen on two phones: each added a line, the server also had a line
    // this phone had not pulled yet; it stays in its place.
    expect(
      mergeVersions('a\nb\nmine', 'a\ntheirs earlier\nb\ntheirs'),
      'a\ntheirs earlier\nb\nmine\ntheirs',
    );
    expect(mergeVersions('same', 'same'), 'same');
    await NoteRecovery(db).useRemote(
      expected: note,
      remote: remote,
      keepLocal: true,
      content: mergeVersions(note.content, remote.content),
    );
    final result = (await db.note('a', note.id))!;
    expect(result.content, 'local\nserver');
    expect(result.etag, 'fresh');
    expect(result.syncState, 'draft');
  });
  test('three-way merge combines edits of different lines', () {
    const base = 'title\n\none\ntwo\nthree';
    // Different lines changed on each side.
    expect(
      mergeThreeWay(
        base,
        'title\n\nONE\ntwo\nthree',
        'title\n\none\ntwo\nTHREE',
      ),
      'title\n\nONE\ntwo\nTHREE',
    );
    // Both appended at the end: both kept, local first.
    expect(
      mergeThreeWay(base, '$base\nmine', '$base\ntheirs'),
      '$base\nmine\ntheirs',
    );
    // The same line added on both sides appears once.
    expect(mergeThreeWay(base, '$base\nsame', '$base\nsame'), '$base\nsame');
    // One side deleted a line the other did not touch.
    expect(
      mergeThreeWay(base, 'title\n\none\nthree', '$base\nnew'),
      'title\n\none\nthree\nnew',
    );
    // An insertion next to a changed line.
    expect(
      mergeThreeWay(
        base,
        'title\n\nONE\ntwo\nthree',
        'title\n\none\nnew\ntwo\nthree',
      ),
      'title\n\nONE\nnew\ntwo\nthree',
    );
    // The same line changed differently cannot be merged.
    expect(
      mergeThreeWay(base, 'title\n\nA\ntwo\nthree', 'title\n\nB\ntwo\nthree'),
      isNull,
    );
    // An insertion inside a range the other side replaced.
    expect(
      mergeThreeWay(base, 'title\n\nX\nthree', 'title\n\none\nnew\ntwo\nthree'),
      isNull,
    );
    expect(mergeThreeWay(base, base, 'changed'), 'changed');
    expect(mergeThreeWay(base, 'changed', base), 'changed');
  });
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
      // The server note comes back on the next pull.
      await db.applyPull('a', await db.readEpoch('a'), [remote]);
      final notes = await db.watchNotes('a').first;
      expect(notes.map((n) => n.content), containsAll(['local', 'server']));
      expect((await db.note('a', note.id))!.content, 'local');
    },
  );
}
