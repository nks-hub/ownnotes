import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextcloudnotes/data/widgets/widget_links.dart';
import 'package:nextcloudnotes/data/widgets/widget_model.dart';
import 'package:nextcloudnotes/data/widgets/widget_publisher.dart';
import 'package:nextcloudnotes/data/widgets/widget_snapshots.dart';
import 'package:nextcloudnotes/data/widgets/widget_storage.dart';
import 'package:notes_store/notes_store.dart';

final class FakeStorage implements WidgetStorage {
  FakeStorage(this.ids);
  final List<String> ids;
  final data = <String, String>{};
  bool locked = false;
  int refreshes = 0;

  @override
  Future<List<String>> instanceIds() async => ids;
  @override
  Future<String?> read(String key) async => data[key];
  @override
  Future<void> write(String key, String? value) async =>
      value == null ? data.remove(key) : data[key] = value;
  @override
  Future<bool> isLocked() async => locked;
  @override
  Future<void> setLocked(bool value) async => locked = value;
  @override
  Future<void> refresh() async => refreshes++;

  void place(WidgetConfig config) =>
      data[WidgetKeys.config(config.instanceId)] = config.encode();
  WidgetSnapshot? snapshot(String id) {
    final raw = data[WidgetKeys.snapshot(id)];
    return raw == null ? null : WidgetSnapshot.decode(raw);
  }

  WidgetConfig? config(String id) {
    final raw = data[WidgetKeys.config(id)];
    return raw == null ? null : WidgetConfig.decode(raw);
  }

  /// What the widget's tap receiver does: queue a command for [instance].
  void queue(String instance, WidgetCommand command) {
    final n = (int.tryParse(data[WidgetKeys.cmdSeq(instance)] ?? '') ?? 0) + 1;
    data[WidgetKeys.cmd(instance, n)] = command.encode();
    data[WidgetKeys.cmdSeq(instance)] = '$n';
  }
}

LocalNote note(
  String id,
  String account,
  String title, {
  String content = '',
  int revision = 1,
}) => LocalNote(
  id: id,
  accountId: account,
  title: title,
  content: content,
  category: '',
  favorite: false,
  readonly: false,
  revision: revision,
  syncState: 'clean',
  updatedAt: revision,
  kind: 'note',
);

void main() {
  group('per-instance configuration', () {
    test('each instance keeps its own account and type', () async {
      final storage = FakeStorage(['1', '2'])
        ..place(
          const WidgetConfig(
            instanceId: '1',
            type: WidgetType.notesList,
            accountId: 'a',
            collection: WidgetCollection(WidgetScope.all),
          ),
        )
        ..place(
          const WidgetConfig(
            instanceId: '2',
            type: WidgetType.singleNote,
            accountId: 'b',
            noteId: 'nb',
          ),
        );
      final notes = {
        'a': [note('na', 'a', 'Alpha')],
        'b': [note('nb', 'b', 'Beta', content: 'Beta\n\nbody text')],
      };
      Future<WidgetSource?> source(String id) async =>
          WidgetSource(notes[id]!, label: 'user-$id');

      await publishWidgets(
        storage,
        source: source,
        locked: false,
        untitled: '…',
        now: 1,
      );
      expect(storage.snapshot('1')!.notes.single.title, 'Alpha');
      expect(storage.snapshot('1')!.accountLabel, 'user-a');
      expect(storage.snapshot('2')!.title, 'Beta');
      expect(storage.snapshot('2')!.accountId, 'b');

      // The app now shows account b: widget 1 is not retargeted.
      notes['b'] = [note('nb', 'b', 'Beta renamed')];
      await publishWidgets(
        storage,
        source: source,
        locked: false,
        untitled: '…',
        onlyAccount: 'b',
        now: 2,
      );
      expect(storage.snapshot('1')!.notes.single.title, 'Alpha');
      expect(storage.snapshot('1')!.accountId, 'a');
      expect(storage.snapshot('2')!.title, 'Beta renamed');
    });

    test('a changed capture time alone does not redraw the widget', () async {
      final storage = FakeStorage(['1'])
        ..place(
          const WidgetConfig(
            instanceId: '1',
            type: WidgetType.notesList,
            accountId: 'a',
            collection: WidgetCollection(WidgetScope.all),
          ),
        );
      Future<WidgetSource?> source(String id) async =>
          WidgetSource([note('n', 'a', 'One')], label: 'x');
      await publishWidgets(storage, source: source, locked: false, untitled: '…', now: 1);
      final after = storage.refreshes;
      await publishWidgets(storage, source: source, locked: false, untitled: '…', now: 99);
      expect(storage.refreshes, after);
    });

    test('the language tag is stored and a change redraws the widgets', () async {
      final storage = FakeStorage(['1']);
      Future<WidgetSource?> source(String id) async => null;
      Future<void> publish(String? language) => publishWidgets(
        storage,
        source: source,
        locked: false,
        untitled: '…',
        language: language,
      );
      await publish('de');
      expect(storage.data[WidgetKeys.language], 'de');
      final after = storage.refreshes;
      await publish('de');
      expect(storage.refreshes, after);
      await publish('en');
      expect(storage.data[WidgetKeys.language], 'en');
      expect(storage.refreshes, after + 1);
      await publish(null);
      expect(storage.data[WidgetKeys.language], 'en');
    });

    test('an app publish without a label keeps the stored one', () async {
      final storage = FakeStorage(['1'])
        ..place(
          const WidgetConfig(
            instanceId: '1',
            type: WidgetType.notesList,
            accountId: 'a',
            collection: WidgetCollection(WidgetScope.all),
          ),
        );
      await publishWidgets(
        storage,
        source: (_) async => WidgetSource([note('n', 'a', 'One')], label: 'ann'),
        locked: false,
        untitled: '…',
      );
      await publishWidgets(
        storage,
        source: (_) async => WidgetSource([note('n', 'a', 'Two')]),
        locked: false,
        untitled: '…',
      );
      expect(storage.snapshot('1')!.accountLabel, 'ann');
      expect(storage.snapshot('1')!.notes.single.title, 'Two');
    });

    test('removing an account clears what its widgets showed', () async {
      final storage = FakeStorage(['1', '2'])
        ..place(
          const WidgetConfig(
            instanceId: '1',
            type: WidgetType.notesList,
            accountId: 'a',
            collection: WidgetCollection(WidgetScope.all),
          ),
        )
        ..place(
          const WidgetConfig(
            instanceId: '2',
            type: WidgetType.notesList,
            accountId: 'b',
            collection: WidgetCollection(WidgetScope.all),
          ),
        );
      Future<WidgetSource?> source(String id) async =>
          WidgetSource([note('n$id', id, 'Title $id')], label: id);
      await publishWidgets(storage, source: source, locked: false, untitled: '…');

      await clearWidgetsOfAccount(storage, 'a');
      expect(storage.snapshot('1'), isNull);
      expect(storage.config('1')!.accountId, isNull);
      expect(storage.config('1')!.isConfigured, isFalse);
      expect(storage.snapshot('2')!.notes.single.title, 'Title b');
      expect(storage.config('2')!.accountId, 'b');
    });

    test('an account missing from the database is cleared by the publisher', () async {
      final storage = FakeStorage(['1'])
        ..place(
          const WidgetConfig(
            instanceId: '1',
            type: WidgetType.checklist,
            accountId: 'gone',
            noteId: 'n',
          ),
        );
      await publishWidgets(
        storage,
        source: (_) async => null,
        locked: false,
        untitled: '…',
      );
      expect(storage.config('1')!.accountId, isNull);
      expect(storage.snapshot('1'), isNull);
    });
  });

  group('privacy', () {
    test('the app lock redacts every widget and unlocking restores them', () async {
      final storage = FakeStorage(['1', '2'])
        ..place(
          const WidgetConfig(
            instanceId: '1',
            type: WidgetType.notesList,
            accountId: 'a',
            collection: WidgetCollection(WidgetScope.all),
          ),
        )
        ..place(
          const WidgetConfig(
            instanceId: '2',
            type: WidgetType.checklist,
            accountId: 'a',
            noteId: 'n',
          ),
        );
      Future<WidgetSource?> source(String id) async => WidgetSource([
        note('n', 'a', 'Secret plan', content: '- [ ] secret task'),
      ], label: 'ann@example');
      await publishWidgets(storage, source: source, locked: false, untitled: '…');
      expect(storage.snapshot('2')!.tasks, isNotEmpty);

      await publishWidgets(storage, source: source, locked: true, untitled: '…');
      expect(storage.locked, isTrue);
      for (final id in ['1', '2']) {
        final raw = storage.data[WidgetKeys.snapshot(id)]!;
        expect(storage.snapshot(id)!.isRedacted, isTrue);
        for (final secret in ['Secret', 'secret', 'ann@example', '"n"', '"a"']) {
          expect(raw.contains(secret), isFalse, reason: '$secret in $raw');
        }
      }

      await publishWidgets(storage, source: source, locked: false, untitled: '…');
      expect(storage.snapshot('1')!.notes.single.title, 'Secret plan');
    });

    test('a late publisher for one account cannot write content while locked', () async {
      final storage = FakeStorage(['1'])
        ..locked = true
        ..place(
          const WidgetConfig(
            instanceId: '1',
            type: WidgetType.notesList,
            accountId: 'a',
            collection: WidgetCollection(WidgetScope.all),
          ),
        );
      await publishWidgets(
        storage,
        source: (_) async => WidgetSource([note('n', 'a', 'Visible?')]),
        locked: true,
        untitled: '…',
        onlyAccount: 'a',
      );
      expect(storage.snapshot('1')!.isRedacted, isTrue);
    });
  });

  group('commands', () {
    late NotesDatabase db;
    late FakeStorage storage;

    setUp(() async {
      db = NotesDatabase(NativeDatabase.memory());
      await db
          .into(db.accounts)
          .insert(
            AccountsCompanion.insert(
              id: 'a',
              server: 'https://cloud.example',
              loginName: 'ann',
              credentialRef: 'ref',
            ),
          );
      storage = FakeStorage(['7']);
    });
    tearDown(() => db.close());

    Future<(String, int)> createNote(String content) async {
      final id = await db.createDraft('a', title: 'List', content: content);
      return (id, (await db.note('a', id))!.revision);
    }

    WidgetCommand command(
      String noteId,
      int revision, {
      String id = 'c1',
      String label = 'milk',
      int occurrence = 0,
      bool checked = true,
      String? hash,
    }) => WidgetCommand(
      commandId: id,
      instanceId: '7',
      accountId: 'a',
      noteId: noteId,
      expectedRevision: revision,
      task: WidgetTaskKey(label, occurrence),
      checked: checked,
      contentHash: hash,
    );

    test('a tick is saved once, however often the command arrives', () async {
      final (id, revision) = await createNote('- [ ] milk\n- [ ] bread\n');
      storage
        ..queue('7', command(id, revision))
        ..queue('7', command(id, revision));
      final changed = await drainWidgetCommands(storage, db);
      expect(changed, {'a'});
      final saved = (await db.note('a', id))!;
      expect(saved.content, '- [x] milk\n- [ ] bread\n');
      expect(saved.revision, revision + 1);
      expect(saved.syncState, 'draft');

      // Delivered again after a restart: nothing changes.
      storage.queue('7', command(id, revision));
      expect(await drainWidgetCommands(storage, db), isEmpty);
      expect((await db.note('a', id))!.revision, revision + 1);
      expect(storage.data[WidgetKeys.stale('7')], isNull);
    });

    test('a command for a note that moved on opens the note instead', () async {
      final (id, revision) = await createNote('- [ ] milk\n');
      await db.saveDraft(
        accountId: 'a',
        id: id,
        revision: revision,
        title: 'List',
        content: '- [ ] milk\n- [ ] eggs\n',
        category: '',
        favorite: false,
      );
      storage.queue('7', command(id, revision));
      expect(await drainWidgetCommands(storage, db), isEmpty);
      expect((await db.note('a', id))!.content, '- [ ] milk\n- [ ] eggs\n');
      expect(storage.data[WidgetKeys.stale('7')], '${revision + 1}');
    });

    test('a revision moved only by a sync still applies', () async {
      const text = '- [ ] milk\n';
      final (id, revision) = await createNote(text);
      // Same text, newer revision: what a sync that only changes state does.
      await db.saveDraft(
        accountId: 'a',
        id: id,
        revision: revision,
        title: 'List',
        content: text,
        category: '',
        favorite: false,
      );
      storage.data[WidgetKeys.stale('7')] = '$revision';
      storage.queue('7', command(id, revision, hash: widgetContentHash(text)));
      expect(await drainWidgetCommands(storage, db), {'a'});
      expect((await db.note('a', id))!.content, '- [x] milk\n');
      expect(storage.data[WidgetKeys.stale('7')], isNull);
    });

    test('a newer revision with other text is not guessed at', () async {
      const text = '- [ ] milk\n';
      final (id, revision) = await createNote(text);
      await db.saveDraft(
        accountId: 'a',
        id: id,
        revision: revision,
        title: 'List',
        content: '- [ ] milk\n- [ ] eggs\n',
        category: '',
        favorite: false,
      );
      storage.queue('7', command(id, revision, hash: widgetContentHash(text)));
      expect(await drainWidgetCommands(storage, db), isEmpty);
      expect((await db.note('a', id))!.content, '- [ ] milk\n- [ ] eggs\n');
      expect(storage.data[WidgetKeys.stale('7')], '${revision + 1}');
    });

    test('ticks tapped in a row all apply', () async {
      final (id, revision) = await createNote('- [ ] milk\n- [ ] bread\n');
      storage
        ..queue('7', command(id, revision, id: 'c1'))
        ..queue('7', command(id, revision, id: 'c2', label: 'bread'));
      await drainWidgetCommands(storage, db);
      final saved = (await db.note('a', id))!;
      expect(saved.content, '- [x] milk\n- [x] bread\n');
      expect(storage.data[WidgetKeys.stale('7')], isNull);
    });

    test('a repeated label is told apart by its occurrence', () async {
      final (id, revision) = await createNote('- [ ] milk\n- [ ] milk\n');
      storage.queue('7', command(id, revision, occurrence: 1));
      await drainWidgetCommands(storage, db);
      expect((await db.note('a', id))!.content, '- [ ] milk\n- [x] milk\n');
    });

    test('the requested state is applied, never toggled', () async {
      final (id, revision) = await createNote('- [x] milk\n');
      storage.queue('7', command(id, revision, checked: true));
      expect(await drainWidgetCommands(storage, db), isEmpty);
      expect((await db.note('a', id))!.content, '- [x] milk\n');
    });

    test('the app lock drops the command without a change', () async {
      final (id, revision) = await createNote('- [ ] milk\n');
      storage
        ..locked = true
        ..queue('7', command(id, revision));
      expect(await drainWidgetCommands(storage, db), isEmpty);
      expect((await db.note('a', id))!.content, '- [ ] milk\n');
      // Unlocked later, the old command does not run.
      storage.locked = false;
      expect(await drainWidgetCommands(storage, db), isEmpty);
      expect((await db.note('a', id))!.content, '- [ ] milk\n');
    });
  });

  group('links', () {
    test('the old and the account-aware forms both open a note', () {
      final old = parseWidgetLink(Uri.parse('ownnotes://note/n1'))!;
      expect((old as OpenNoteLink).noteId, 'n1');
      expect(old.accountId, isNull);
      final now = parseWidgetLink(Uri.parse('ownnotes://note/acc/n1'))!;
      expect((now as OpenNoteLink).accountId, 'acc');
      expect(now.noteId, 'n1');
    });

    test('new note links carry account and kind', () {
      final plain = parseWidgetLink(Uri.parse('ownnotes://new'))! as NewNoteLink;
      expect(plain.accountId, isNull);
      expect(plain.kind, WidgetNewKind.note);
      final daily =
          parseWidgetLink(Uri.parse('ownnotes://new/acc?kind=daily'))!
              as NewNoteLink;
      expect(daily.accountId, 'acc');
      expect(daily.kind, WidgetNewKind.daily);
    });

    test('open and unrelated links', () {
      expect(parseWidgetLink(Uri.parse('ownnotes://open')), isA<OpenAppLink>());
      expect(parseWidgetLink(Uri.parse('https://example.org/x')), isNull);
      expect(parseWidgetLink(Uri.parse('ownnotes://note')), isNull);
    });
  });
}
