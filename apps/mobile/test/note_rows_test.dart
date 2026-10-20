import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextcloudnotes/features/category_panel.dart';
import 'package:nextcloudnotes/features/note_rows.dart';
import 'package:nextcloudnotes/features/note_tile.dart';
import 'package:nextcloudnotes/l10n/app_localizations.dart';
import 'package:notes_store/notes_store.dart';

LocalNote note({
  String title = 'Title',
  String content = '',
  String category = '',
  String syncState = 'clean',
  bool favorite = false,
}) => LocalNote(
  id: 'n1',
  accountId: 'a',
  title: title,
  content: content,
  category: category,
  favorite: favorite,
  readonly: false,
  revision: 1,
  syncState: syncState,
  updatedAt: DateTime.now().millisecondsSinceEpoch,
);

Widget app(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
  locale: locale,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  group('noteExcerpt', () {
    test('skips a first line that repeats the title', () {
      expect(
        noteExcerpt('Plan', '# Plan\n\nFirst **bold** step'),
        'First bold step',
      );
    });

    test('keeps the first line when it differs from the title', () {
      expect(noteExcerpt('Plan', 'Other\nmore'), 'Other more');
    });

    test('strips list, task, quote and link markers', () {
      const content =
          '- [x] done thing\n* item\n> quoted\n'
          '2. second [site](http://x.y) ![i](a.png)\n---\n';
      expect(noteExcerpt('T', content), 'done thing item quoted second site');
    });

    test('caps the length and never reads past it', () {
      final long = List.filled(5000, 'word').join(' ');
      final excerpt = noteExcerpt('T', 'a\n$long\n$long');
      expect(excerpt.length, lessThanOrEqualTo(160));
      expect(excerpt.startsWith('a word'), isTrue);
    });

    test('does not split an emoji at the cap', () {
      final excerpt = noteExcerpt('T', '${'x' * 159}😀tail');
      expect(excerpt, 'x' * 159);
    });

    test('empty content gives an empty excerpt', () {
      expect(noteExcerpt('T', ''), '');
    });
  });

  test('taskProgress counts checked and all task items', () {
    expect(
      taskProgress('- [ ] a\n- [x] b\n  * [X] c\n- not a task\n[ ] no dash'),
      (done: 2, total: 3),
    );
    expect(taskProgress('plain'), (done: 0, total: 0));
  });

  group('NoteRow', () {
    test('derives excerpt, tasks and attachment flag', () {
      final row = NoteRow.of(
        note(
          title: '',
          content:
              '# Shopping\n- [x] milk\n- [ ] eggs\n![a](.attachments.1/a.png)',
        ),
      );
      expect(row.title, 'Shopping');
      expect(row.excerpt, 'milk eggs');
      expect((row.tasksDone, row.tasksTotal), (1, 2));
      expect(row.attachments, isTrue);
      expect(row.haystack, contains('shopping'));
    });

    test('scope filtering includes children of a category', () {
      final row = NoteRow.of(note(category: 'Work/Projects'));
      expect(row.inScope(NoteScope.category, 'Work'), isTrue);
      expect(row.inScope(NoteScope.category, 'Work/Projects'), isTrue);
      expect(row.inScope(NoteScope.category, 'Wor'), isFalse);
      expect(row.inScope(NoteScope.uncategorised, ''), isFalse);
      expect(row.inScope(NoteScope.favorites, ''), isFalse);
    });
  });

  group('buildCategoryTree', () {
    test('creates virtual parents and sums counts', () {
      final tree = buildCategoryTree({
        'Work/Projects': 2,
        'Work/Meetings': 1,
        'Home': 4,
      });
      expect(tree.map((n) => n.path), ['Home', 'Work']);
      final work = tree.last;
      expect(work.count, 3);
      expect(work.children.map((n) => n.name), ['Meetings', 'Projects']);
      expect(work.children.last.path, 'Work/Projects');
    });

    test('a parent with its own notes adds them to the children', () {
      final tree = buildCategoryTree({'Work': 1, 'Work/A/B': 2});
      expect(tree.single.count, 3);
      expect(tree.single.children.single.children.single.path, 'Work/A/B');
    });
  });

  testWidgets('CategoryPanel expands and selects', (tester) async {
    final tree = buildCategoryTree({'Work/Projects': 2});
    var toggled = '';
    NoteScope? selected;
    String? selectedPath;
    Widget panel(Set<String> expanded) => app(
      CategoryPanel(
        tree: tree,
        total: 5,
        favorites: 1,
        uncategorised: 3,
        scope: NoteScope.all,
        category: '',
        expanded: expanded,
        onSelect: (s, c) {
          selected = s;
          selectedPath = c;
        },
        onToggle: (p) => toggled = p,
      ),
    );
    await tester.pumpWidget(panel({}));
    expect(find.text('All notes'), findsOneWidget);
    expect(find.text('Uncategorised'), findsOneWidget);
    expect(find.text('Projects'), findsNothing);
    await tester.tap(find.byIcon(Icons.chevron_right));
    expect(toggled, 'Work');
    await tester.pumpWidget(panel({'Work'}));
    await tester.tap(find.text('Projects'));
    expect(selected, NoteScope.category);
    expect(selectedPath, 'Work/Projects');
  });

  testWidgets('NoteTile shows progress, category and explicit state', (
    tester,
  ) async {
    final row = NoteRow.of(
      note(
        title: 'Trip',
        content: '# Trip\n- [x] a\n- [ ] b\n.attachments.',
        category: 'Travel',
        syncState: 'needsDecision',
        favorite: true,
      ),
    );
    await tester.pumpWidget(
      app(NoteTile(row: row, showCategory: true, onTap: () {})),
    );
    expect(find.text('Trip'), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);
    expect(find.text('Travel'), findsOneWidget);
    expect(find.text('Needs decision'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_upload_outlined), findsNothing);
    expect(find.byIcon(Icons.star), findsOneWidget);
  });

  testWidgets('NoteTile of a clean note has no state label', (tester) async {
    final row = NoteRow.of(note(content: 'text'));
    await tester.pumpWidget(
      app(NoteTile(row: row, showCategory: false, onTap: () {})),
    );
    expect(find.text('Waiting'), findsNothing);
    expect(find.text('Just now'), findsOneWidget);
  });
}
