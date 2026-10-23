import 'package:flutter/material.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextcloudnotes/features/collection/editor_pane.dart';
import 'package:nextcloudnotes/features/collection/notebook_actions.dart';
import 'package:nextcloudnotes/features/search/search_filters.dart';
import 'package:nextcloudnotes/features/note_rows.dart';
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
  kind: 'note',
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
  test(
    'incoming Notes files belong to shared scope without changing category',
    () {
      final incoming = note(
        category: 'Work',
      ).copyWith(sharedWithMe: const Value(true));
      final outgoing = note().copyWith(sharedByMe: const Value(true));
      final dav = note().copyWith(kind: 'shared');
      final row = NoteRow.of(incoming);
      expect(row.isShared, isTrue);
      expect(row.inScope(NoteScope.shared, ''), isTrue);
      expect(row.inScope(NoteScope.category, 'Work'), isTrue);
      final owner = NoteRow.of(outgoing);
      expect(owner.isShared, isTrue);
      expect(owner.inScope(NoteScope.shared, ''), isFalse);
      expect(owner.inScope(NoteScope.uncategorised, ''), isTrue);
      expect(const NoteFilters(shared: true).matches(owner), isTrue);
      final counts = countNotes([incoming, outgoing, dav]);
      expect(counts.shared, 2);
      expect(counts.uncategorised, 1);
      expect(counts.categories, {'Work': 1});
      final refreshed = NoteRow.of(
        incoming.copyWith(sharedWithMe: const Value(false)),
        row,
      );
      expect(refreshed.isShared, isFalse);
    },
  );
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

  group('selectRows', () {
    final rows = [
      NoteRow.of(note(title: 'Alpha', content: '- [ ] a', favorite: true)),
      NoteRow.of(note(title: 'beta', content: '- [x] b')),
      NoteRow.of(note(title: 'Gamma', category: 'Work/Plans')),
    ];

    test('filters combine with the query', () {
      expect(
        selectRows(
          rows,
          scope: NoteScope.all,
          filters: const NoteFilters(unfinishedTasks: true),
        ).map((r) => r.title),
        ['Alpha'],
      );
      expect(
        selectRows(
          rows,
          scope: NoteScope.all,
          query: 'WORK',
        ).map((r) => r.title),
        ['Gamma'],
      );
    });

    test('title sort ignores case, favorites first keeps the order', () {
      expect(
        selectRows(
          rows,
          scope: NoteScope.all,
          sort: SortMode.title,
        ).map((r) => r.title),
        ['Alpha', 'beta', 'Gamma'],
      );
      expect(
        selectRows(
          rows,
          scope: NoteScope.all,
          sort: SortMode.favoritesFirst,
        ).map((r) => r.title),
        ['Alpha', 'beta', 'Gamma'],
      );
    });

    test('filters survive a round trip through JSON', () {
      const f = NoteFilters(favorites: true, sync: SyncFilter.decision);
      expect(NoteFilters.fromJson(f.toJson()), f);
    });
  });

  group('notebookLayout', () {
    test('follows the width and gives way to large text', () {
      expect(notebookLayout(411, 1), NotebookLayout.phone);
      expect(notebookLayout(599, 1), NotebookLayout.phone);
      // Inner display of a foldable.
      expect(notebookLayout(673, 1), NotebookLayout.twoPane);
      expect(notebookLayout(673, 1.3), NotebookLayout.phone);
      expect(notebookLayout(673, 1.3, fold: true), NotebookLayout.twoPane);
      expect(notebookLayout(840, 1), NotebookLayout.twoPane);
      expect(notebookLayout(1280, 1), NotebookLayout.threePane);
      expect(notebookLayout(1280, 1.5), NotebookLayout.twoPane);
      expect(notebookLayout(1280, 2), NotebookLayout.phone);
    });

    test('the list shares a narrow window with the editor', () {
      expect(listWidthFor(673), closeTo(302.85, 0.01));
      expect(listWidthFor(600), 270);
      expect(listWidthFor(900), listPaneWidth);
    });
  });

  group('bulk permissions', () {
    final plain = NoteRow.of(note());
    final readonly = NoteRow.of(note().copyWith(readonly: true));
    final shared = NoteRow.of(note().copyWith(kind: 'shared'));
    final attached = NoteRow.of(note(content: '![a](.attachments.1/a.png)'));

    test('a read-only note can only change its star', () {
      expect(canFavorite(readonly.note), isTrue);
      expect(canMove(readonly), isFalse);
      expect(canDelete(readonly.note), isFalse);
    });

    test('a shared note allows none of them', () {
      expect(canFavorite(shared.note), isFalse);
      expect(canMove(shared), isFalse);
      expect(canDelete(shared.note), isFalse);
    });

    test('a note with attachments cannot change category', () {
      expect(canMove(attached), isFalse);
      expect(canDelete(attached.note), isTrue);
      expect(canMove(plain), isTrue);
    });
  });
}
