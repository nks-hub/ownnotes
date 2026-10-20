import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextcloudnotes/data/widgets/widget_model.dart';
import 'package:nextcloudnotes/data/widgets/widget_snapshots.dart';
import 'package:notes_store/notes_store.dart';

LocalNote note({
  String id = 'n1',
  String account = 'a',
  String title = 'Shopping',
  String content = '',
  String category = '',
  bool favorite = false,
  int revision = 3,
  int updatedAt = 1,
}) => LocalNote(
  id: id,
  accountId: account,
  title: title,
  content: content,
  category: category,
  favorite: favorite,
  readonly: false,
  revision: revision,
  syncState: 'clean',
  updatedAt: updatedAt,
  kind: 'note',
);

WidgetCommand command({
  String id = 'c1',
  int revision = 3,
  String label = 'milk',
  int occurrence = 0,
  bool checked = true,
}) => WidgetCommand(
  commandId: id,
  instanceId: 'w1',
  accountId: 'a',
  noteId: 'n1',
  expectedRevision: revision,
  task: WidgetTaskKey(label, occurrence),
  checked: checked,
);

void main() {
  group('serialisation', () {
    test('config round trips and says when it needs configuring', () {
      const config = WidgetConfig(
        instanceId: '12',
        type: WidgetType.notesList,
        accountId: 'a',
        collection: WidgetCollection(WidgetScope.category, 'Work/Plans'),
        appearance: WidgetAppearance.dark,
      );
      final back = WidgetConfig.decode(config.encode());
      expect(back.type, WidgetType.notesList);
      expect(back.accountId, 'a');
      expect(back.collection!.category, 'Work/Plans');
      expect(back.appearance, WidgetAppearance.dark);
      expect(back.isConfigured, isTrue);
      expect(
        const WidgetConfig(instanceId: '1', type: WidgetType.checklist, accountId: 'a').isConfigured,
        isFalse,
      );
      expect(
        const WidgetConfig(instanceId: '1', type: WidgetType.quickNote).isConfigured,
        isFalse,
      );
    });

    test('snapshot round trips content, tasks and revision', () {
      const snapshot = WidgetSnapshot(
        instanceId: '12',
        type: WidgetType.checklist,
        capturedAt: 1700000000000,
        accountId: 'a',
        accountLabel: 'Personal',
        noteId: 'n1',
        revision: 3,
        title: 'Shopping',
        tasks: [
          WidgetTaskEntry(WidgetTaskKey('milk', 0), false),
          WidgetTaskEntry(WidgetTaskKey('milk', 1), true),
        ],
      );
      final back = WidgetSnapshot.decode(snapshot.encode());
      expect(back.revision, 3);
      expect(back.tasksDone, 1);
      expect(back.tasksTotal, 2);
      expect(back.tasks[1].key, const WidgetTaskKey('milk', 1));
      expect(back.isRedacted, isFalse);
    });

    test('command round trips', () {
      final back = WidgetCommand.decode(command().encode());
      expect(back.commandId, 'c1');
      expect(back.expectedRevision, 3);
      expect(back.task, const WidgetTaskKey('milk', 0));
      expect(back.checked, isTrue);
    });
  });

  group('redaction', () {
    final notes = [
      note(
        content: '- [ ] milk\n- [x] eggs',
        category: 'Private/Taxes',
        title: 'Secret plan',
      ),
    ];

    test('a locked build holds nothing but instance, type and time', () {
      for (final type in WidgetType.values) {
        final snapshot = buildWidgetSnapshot(
          WidgetConfig(
            instanceId: 'w1',
            type: type,
            accountId: 'a',
            noteId: 'n1',
            collection: const WidgetCollection(WidgetScope.all),
          ),
          notes,
          locked: true,
          untitled: 'Untitled',
          now: 5,
          accountLabel: 'Personal',
        );
        expect(snapshot.isRedacted, isTrue);
        final json = snapshot.encode();
        for (final secret in ['Secret', 'Taxes', 'milk', 'Personal', 'n1', 'revision', 'tasks']) {
          expect(json, isNot(contains(secret)), reason: '$type leaks $secret');
        }
        expect(jsonDecode(json), {
          'schema': 1,
          'instanceId': 'w1',
          'type': type.name,
          'capturedAt': 5,
          'privacy': 'redacted',
        });
      }
    });

    test('a stored redacted snapshot never yields content when read', () {
      final back = WidgetSnapshot.fromJson({
        'instanceId': 'w1',
        'type': 'singleNote',
        'capturedAt': 1,
        'privacy': 'redacted',
        'title': 'Secret plan',
        'tasks': [
          {'key': {'label': 'x', 'occurrence': 0}, 'checked': false},
        ],
      });
      expect(back.isRedacted, isTrue);
      expect(back.title, isNull);
      expect(back.tasks, isEmpty);
    });

    test('an unknown privacy value counts as redacted', () {
      final back = WidgetSnapshot.fromJson({
        'instanceId': 'w1',
        'type': 'singleNote',
        'capturedAt': 1,
        'privacy': 'something',
        'title': 'Secret plan',
      });
      expect(back.isRedacted, isTrue);
    });
  });

  group('snapshot building', () {
    final notes = [
      note(id: 'n1', title: 'Old', updatedAt: 1, category: 'Work'),
      note(id: 'n2', title: 'New', updatedAt: 9, favorite: true),
      note(id: 'n3', account: 'other', title: 'Other account', updatedAt: 10),
      note(id: 'n4', title: '', content: '# From content\nbody', updatedAt: 5),
    ];

    test('list widget keeps its own account and newest first', () {
      final s = buildWidgetSnapshot(
        const WidgetConfig(
          instanceId: 'w',
          type: WidgetType.notesList,
          accountId: 'a',
          collection: WidgetCollection(WidgetScope.all),
        ),
        notes,
        locked: false,
        untitled: 'Untitled',
        now: 1,
      );
      expect(s.notes.map((n) => n.title), ['New', 'From content', 'Old']);
      expect(s.notes.first.favorite, isTrue);
    });

    test('list widget filters by category subtree and favorites', () {
      WidgetSnapshot build(WidgetCollection c) => buildWidgetSnapshot(
        WidgetConfig(
          instanceId: 'w',
          type: WidgetType.notesList,
          accountId: 'a',
          collection: c,
        ),
        notes,
        locked: false,
        untitled: 'Untitled',
        now: 1,
      );
      expect(
        build(const WidgetCollection(WidgetScope.category, 'Work')).notes.map((n) => n.id),
        ['n1'],
      );
      expect(build(const WidgetCollection(WidgetScope.favorites)).notes.map((n) => n.id), ['n2']);
      expect(build(const WidgetCollection(WidgetScope.uncategorised)).notes, hasLength(2));
    });

    test('checklist widget lists tasks with their occurrence', () {
      final s = buildWidgetSnapshot(
        const WidgetConfig(
          instanceId: 'w',
          type: WidgetType.checklist,
          accountId: 'a',
          noteId: 'n9',
        ),
        [note(id: 'n9', content: '- [ ] milk\n- [x] milk\n```\n- [ ] code\n```')],
        locked: false,
        untitled: 'Untitled',
        now: 1,
      );
      expect(s.revision, 3);
      expect(s.tasks.map((t) => (t.key.label, t.key.occurrence, t.checked)), [
        ('milk', 0, false),
        ('milk', 1, true),
      ]);
    });

    test('a note of another account is never shown', () {
      final s = buildWidgetSnapshot(
        const WidgetConfig(
          instanceId: 'w',
          type: WidgetType.singleNote,
          accountId: 'a',
          noteId: 'n3',
        ),
        notes,
        locked: false,
        untitled: 'Untitled',
        now: 1,
      );
      expect(s.title, isNull);
      expect(s.noteId, isNull);
    });
  });

  group('commands', () {
    final n = note(content: '- [ ] milk\n- [ ] eggs\n- [ ] milk');

    WidgetCommandResult run(
      WidgetCommand c, {
      LocalNote? target,
      Set<String> applied = const {},
      bool locked = false,
    }) => resolveWidgetCommand(
      c,
      note: target ?? n,
      applied: applied,
      locked: locked,
    );

    test('sets the requested state on the right duplicate', () {
      final r = run(command(occurrence: 1));
      expect(r, isA<ApplyCommand>());
      expect((r as ApplyCommand).content, '- [ ] milk\n- [ ] eggs\n- [x] milk');
    });

    test('a repeated command id changes nothing', () {
      expect(run(command(), applied: {'c1'}), isA<DuplicateCommand>());
    });

    test('a command asking for the current state is a no-op', () {
      expect(run(command(checked: false)), isA<DuplicateCommand>());
    });

    test('a stale revision opens the note', () {
      expect(run(command(revision: 2)), isA<OpenNoteCommand>());
    });

    test('a task that is gone or ambiguous opens the note', () {
      expect(run(command(label: 'bread')), isA<OpenNoteCommand>());
      expect(run(command(occurrence: 5)), isA<OpenNoteCommand>());
      expect(
        resolveWidgetCommand(command(), note: null, applied: {}, locked: false),
        isA<OpenNoteCommand>(),
      );
    });

    test('the lock blocks everything, even a duplicate', () {
      expect(run(command(), locked: true), isA<BlockedCommand>());
      expect(run(command(), applied: {'c1'}, locked: true), isA<BlockedCommand>());
    });

    test('a note of another account is not touched', () {
      expect(
        run(command(), target: note(account: 'other', content: '- [ ] milk')),
        isA<OpenNoteCommand>(),
      );
    });
  });
}
