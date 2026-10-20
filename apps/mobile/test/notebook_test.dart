import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:nextcloudnotes/data/runtime.dart';
import 'package:nextcloudnotes/design/design.dart';
import 'package:nextcloudnotes/features/category_panel.dart';
import 'package:nextcloudnotes/features/collection/saved_views.dart';
import 'package:nextcloudnotes/features/collection/status_area.dart';
import 'package:nextcloudnotes/features/editor.dart';
import 'package:nextcloudnotes/features/note_rows.dart';
import 'package:nextcloudnotes/features/note_tile.dart';
import 'package:nextcloudnotes/l10n/app_localizations.dart';
import 'package:nextcloudnotes/main.dart';
import 'package:notes_protocol/notes_protocol.dart';
import 'package:notes_store/notes_store.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

class _Vault implements CredentialVault {
  final entries = <String, String>{};
  @override
  Future<void> write(String reference, String password) async {
    entries[reference] = password;
  }

  @override
  Future<String?> read(String reference) async => entries[reference];
  @override
  Future<void> delete(String reference) async {
    entries.remove(reference);
  }

  @override
  Future<Set<String>> references() async => entries.keys.toSet();
}

LocalNote _note({
  String title = 'Title',
  String content = '',
  String category = '',
  String syncState = 'clean',
  bool favorite = false,
  bool readonly = false,
  String kind = 'note',
  bool? unreadable,
}) => LocalNote(
  id: 'n1',
  accountId: 'a',
  title: title,
  content: content,
  category: category,
  favorite: favorite,
  readonly: readonly,
  revision: 1,
  syncState: syncState,
  updatedAt: DateTime.now().millisecondsSinceEpoch,
  kind: kind,
  unreadable: unreadable,
);

Widget _wrap(
  Widget child, {
  double scale = 1,
  Locale locale = const Locale('en'),
}) => MaterialApp(
  locale: locale,
  theme: OwnTheme.light(),
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: Scaffold(body: child),
);

class _Seed {
  const _Seed(
    this.title, {
    this.content = '',
    this.category = '',
    this.favorite = false,
    this.readonly = false,
    this.syncState = 'clean',
    this.remoteId,
    this.deleteError,
  });
  final String title;
  final String content;
  final String category;
  final bool favorite;
  final bool readonly;
  final String syncState;
  final int? remoteId;
  final String? deleteError;
}

class _Env {
  _Env(this.runtime, this.accountId);
  final AppRuntime runtime;
  final String accountId;
  NotesDatabase get db => runtime.database;
}

/// An app test that also lets drift's stream clean-up timers run out, as
/// the other widget tests of this project do.
void appTest(String name, Future<void> Function(WidgetTester tester) body) =>
    testWidgets(name, (tester) async {
      await body(tester);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });

void main() {
  setUpAll(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  Future<_Env> open(WidgetTester tester, List<_Seed> seeds) async {
    final runtime = (await tester.runAsync(
      () async => AppRuntime(
        NotesDatabase(NativeDatabase.memory()),
        _Vault(),
        transport: () => MockClient((_) async => throw Exception('offline')),
      ),
    ))!;
    addTearDown(runtime.close);
    final id = (await tester.runAsync(() async {
      final id = await runtime.accounts.add(
        LoginCredentials(
          server: ServerBase.parse('https://cloud.test'),
          loginName: 'test',
          appPassword: 'secret',
        ),
      );
      final db = runtime.database;
      var n = 0;
      for (final s in seeds) {
        n++;
        await db
            .into(db.localNotes)
            .insert(
              LocalNotesCompanion.insert(
                id: 'n$n',
                accountId: id,
                title: s.title,
                content: s.content,
                category: Value(s.category),
                favorite: Value(s.favorite),
                readonly: Value(s.readonly),
                syncState: Value(s.syncState),
                remoteId: Value(s.remoteId),
                etag: Value(s.remoteId == null ? null : 'e$n'),
                deleteError: Value(s.deleteError),
                // Newest first in the order the seeds are given.
                updatedAt: 1000 - n,
              ),
            );
      }
      return id;
    }))!;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [runtimeProvider.overrideWithValue(runtime)],
        child: const OwnNotesApp(),
      ),
    );
    await settle(tester);
    return _Env(runtime, id);
  }

  group('category panel', () {
    final tree = buildCategoryTree({'Work/Projects': 2, 'Home': 1});

    Widget panel({
      Set<String> expanded = const {},
      void Function(NoteScope, String)? onSelect,
      ValueChanged<String>? onToggle,
      List<CategoryNode>? nodes,
      String subtree = '',
      ValueChanged<String>? onSubtree,
      int count = 0,
    }) => _wrap(
      CategoryPanel(
        tree: nodes ?? tree,
        total: count,
        favorites: count,
        uncategorised: count,
        scope: NoteScope.all,
        category: '',
        expanded: expanded,
        subtree: subtree,
        onSubtree: onSubtree,
        onSelect: onSelect ?? (_, _) {},
        onToggle: onToggle ?? (_) {},
      ),
    );

    testWidgets('selecting a category and expanding it are separate taps', (
      tester,
    ) async {
      final selected = <String>[];
      final toggled = <String>[];
      await tester.pumpWidget(
        panel(
          onSelect: (s, c) => selected.add('${s.name}:$c'),
          onToggle: toggled.add,
        ),
      );
      await tester.tap(find.text('Work'));
      expect(selected, ['category:Work']);
      expect(toggled, isEmpty);
      await tester.tap(find.byTooltip('Expand Work'));
      expect(toggled, ['Work']);
      expect(selected, hasLength(1));
      // The toggle target is a full 48 px square.
      expect(
        tester.getSize(
          find.widgetWithIcon(IconButton, Icons.expand_more).first,
        ),
        const Size(48, 48),
      );
    });

    testWidgets('empty destinations stay in the list', (tester) async {
      await tester.pumpWidget(panel(nodes: const []));
      for (final label in [
        'All notes',
        'Favorites',
        'Uncategorised',
        'Shared with me',
        'Needs attention',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
    });

    testWidgets('a fourth level opens as its own subtree with a breadcrumb', (
      tester,
    ) async {
      final deep = buildCategoryTree({'A/B/C/D': 1});
      final opened = <String>[];
      await tester.pumpWidget(
        panel(nodes: deep, expanded: {'A', 'A/B'}, onSubtree: opened.add),
      );
      expect(find.text('D'), findsNothing);
      await tester.tap(find.byTooltip('Show C on its own'));
      expect(opened, ['A/B/C']);
      await tester.pumpWidget(panel(nodes: deep, subtree: 'A/B/C'));
      expect(find.text('All categories'), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      expect(find.text('D'), findsOneWidget);
    });
  });

  group('note rows', () {
    testWidgets('state lines wrap at 200% text in a narrow window', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final rows = [
        NoteRow.of(
          _note(
            title: 'Meeting notes with a really long title that must wrap',
            content: '- [x] a\n- [ ] b\n![i](.attachments.1/a.png)',
            category: 'Work/Planning/Quarterly',
            syncState: 'needsDecision',
            favorite: true,
          ),
        ),
        NoteRow.of(_note(syncState: 'draft', kind: 'shared', readonly: true)),
        NoteRow.of(_note(syncState: 'sending')),
        NoteRow.of(_note(unreadable: true)),
      ];
      await tester.pumpWidget(
        _wrap(
          ListView(
            children: [
              for (final r in rows)
                NoteTile(
                  row: r,
                  showCategory: true,
                  onTap: () {},
                  onMenu: () {},
                  onRetry: () {},
                ),
            ],
          ),
          scale: 2,
          locale: const Locale('cs'),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Čeká na vaše rozhodnutí'), findsOneWidget);
      expect(find.text('Sdíleno · Jen pro čtení'), findsOneWidget);
    });

    testWidgets('German-length state texts grow the line, never ellipsis', (
      tester,
    ) async {
      Future<double> height(double width, double scale) async {
        await tester.binding.setSurfaceSize(Size(width, 900));
        await tester.pumpWidget(
          _wrap(
            const Column(
              children: [
                NoteStateLine(
                  text: 'Speichern auf diesem Gerät nicht möglich',
                  icon: Icons.error_outline,
                  tone: OwnTone.error,
                ),
                NoteStateLine(
                  text: 'Benötigt deine Entscheidung',
                  icon: Icons.rule,
                  tone: OwnTone.decision,
                ),
              ],
            ),
            scale: scale,
          ),
        );
        expect(tester.takeException(), isNull);
        return tester
            .widgetList(find.byType(NoteStateLine))
            .fold<double>(
              0,
              (sum, w) => sum + tester.getSize(find.byWidget(w)).height,
            );
      }

      addTearDown(() => tester.binding.setSurfaceSize(null));
      final wide = await height(600, 1);
      final narrow = await height(200, 2);
      expect(narrow, greaterThan(wide * 2));
      for (final t in tester.widgetList<Text>(find.byType(Text))) {
        expect(t.overflow, isNull);
        expect(t.maxLines, isNull);
      }
    });

    testWidgets('an unavailable note offers Retry', (tester) async {
      var retried = 0;
      await tester.pumpWidget(
        _wrap(
          NoteTile(
            row: NoteRow.of(_note(unreadable: true)),
            showCategory: false,
            onTap: () {},
            onRetry: () => retried++,
          ),
        ),
      );
      expect(find.text('Cannot refresh this note'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      expect(retried, 1);
    });
  });

  group('notebook', () {
    appTest('searching survives opening a note and coming back', (
      tester,
    ) async {
      await open(tester, [
        const _Seed('Alpha'),
        const _Seed('Beta'),
        const _Seed('Alphabet'),
      ]);
      await tester.tap(find.byTooltip('Search notes'));
      await settle(tester);
      await tester.enterText(find.byType(TextField), 'alpha');
      await tester.pump(const Duration(milliseconds: 300));
      await settle(tester);
      expect(find.text('Beta'), findsNothing);
      expect(find.text('Alphabet'), findsOneWidget);

      await tester.tap(find.text('Alpha'));
      await settle(tester);
      expect(find.byType(EditorScreen), findsOneWidget);
      await tester.pageBack();
      await settle(tester);

      expect(find.byType(EditorScreen), findsNothing);
      expect(find.widgetWithText(TextField, 'alpha'), findsOneWidget);
      expect(find.text('Beta'), findsNothing);
      expect(find.text('Alphabet'), findsOneWidget);
    });

    appTest('a search without results keeps the query and clears filters', (
      tester,
    ) async {
      await open(tester, [const _Seed('Alpha')]);
      await tester.tap(find.byTooltip('Search notes'));
      await settle(tester);
      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.widgetWithText(FilterChip, 'Favorites'));
      await settle(tester);
      expect(find.text('No note matches your search.'), findsOneWidget);
      expect(find.text('“zzz”'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Clear filters'));
      await settle(tester);
      expect(find.text('No note matches your search.'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'zzz'), findsOneWidget);
    });

    appTest('the waiting row collapses once the work is done', (tester) async {
      final env = await open(tester, [
        const _Seed('Pending note', syncState: 'draft'),
      ]);
      expect(find.text('Offline · changes saved on device'), findsOneWidget);

      await tester.runAsync(() async {
        final db = env.db;
        await (db.update(
          db.localNotes,
        )).write(const LocalNotesCompanion(syncState: Value('clean')));
        await db.recordSyncResult(env.accountId, completed: true);
      });
      await settle(tester);
      // A moment of "Up to date", then no row at all.
      expect(find.textContaining('Up to date · checked'), findsOneWidget);
      // The settle timer was started inside runAsync, so it runs in real time.
      await tester.runAsync(() => Future<void>.delayed(statusSettleDelay));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('Up to date'), findsNothing);
      expect(find.textContaining('Offline'), findsNothing);
      expect(find.text('Offline'), findsNothing);
    });

    appTest('long press selects; read-only notes block move and delete', (
      tester,
    ) async {
      await open(tester, [
        const _Seed('Mine'),
        const _Seed('Locked', readonly: true),
      ]);
      await tester.longPress(find.text('Mine'));
      await settle(tester);
      expect(find.text('1 selected'), findsOneWidget);
      await tester.tap(find.text('Locked'));
      await settle(tester);
      expect(find.text('2 selected'), findsOneWidget);

      IconButton button(IconData icon) =>
          tester.widget<IconButton>(find.widgetWithIcon(IconButton, icon));
      expect(button(Icons.delete_outline).onPressed, isNull);
      expect(button(Icons.drive_file_move_outlined).onPressed, isNull);
      // The star may still change on a read-only note.
      expect(button(Icons.star_outline).onPressed, isNotNull);
      expect(button(Icons.ios_share).onPressed, isNotNull);
      expect(find.textContaining('Delete is unavailable'), findsOneWidget);
      expect(find.textContaining('Move is unavailable'), findsOneWidget);
    });

    appTest('bulk delete names the count and Undo brings the notes back', (
      tester,
    ) async {
      final env = await open(tester, [
        const _Seed('Local only'),
        const _Seed('On the server', remoteId: 7),
      ]);
      await tester.longPress(find.text('Local only'));
      await settle(tester);
      await tester.tap(find.text('On the server'));
      await settle(tester);
      await tester.tap(find.widgetWithIcon(IconButton, Icons.delete_outline));
      await settle(tester);
      expect(find.text('Delete 2 notes?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await settle(tester);

      expect(find.text('2 notes deleted'), findsOneWidget);
      expect(find.text('Local only'), findsNothing);
      await tester.runAsync(() async {
        final rows = await env.db.select(env.db.localNotes).get();
        expect(rows.map((r) => r.syncState), ['deleting']);
      });

      await tester.tap(find.text('Undo'));
      await settle(tester);
      expect(find.text('Local only'), findsOneWidget);
      expect(find.text('On the server'), findsOneWidget);
      await tester.runAsync(() async {
        final rows = await env.db.select(env.db.localNotes).get();
        expect(rows, hasLength(2));
        expect(rows.where((r) => r.syncState == 'deleting'), isEmpty);
      });
    });

    appTest('a trailing swipe favorites without deleting anything', (
      tester,
    ) async {
      final env = await open(tester, [const _Seed('Swipe me')]);
      await tester.drag(find.text('Swipe me'), const Offset(-400, 0));
      await settle(tester);
      expect(find.text('Swipe me'), findsOneWidget);
      await tester.runAsync(() async {
        final n = await env.db.select(env.db.localNotes).getSingle();
        expect(n.favorite, isTrue);
      });
      // A leading swipe only offers Move and Delete.
      await tester.drag(find.text('Swipe me'), const Offset(400, 0));
      await settle(tester);
      expect(find.widgetWithText(ListTile, 'Move'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Delete'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Open'), findsNothing);
      await tester.runAsync(() async {
        expect(await env.db.select(env.db.localNotes).get(), hasLength(1));
      });
    });

    appTest('every menu and sheet row has a leading icon', (tester) async {
      await open(tester, [const _Seed('Alpha', category: 'Work')]);

      void allHaveIcons(Finder rows) {
        expect(rows, findsWidgets);
        for (final tile in tester.widgetList<ListTile>(rows)) {
          expect(tile.leading, isNotNull, reason: '${tile.title}');
        }
      }

      await tester.tap(find.byTooltip('More options'));
      await settle(tester);
      final items = find.byType(PopupMenuItem<String>);
      expect(items, findsNWidgets(5));
      for (final item in tester.widgetList<PopupMenuItem<String>>(items)) {
        expect(
          find.descendant(of: find.byWidget(item), matching: find.byType(Icon)),
          findsOneWidget,
        );
      }
      await tester.tapAt(const Offset(5, 5));
      await settle(tester);

      await tester.tap(find.byTooltip('New note'));
      await settle(tester);
      allHaveIcons(find.byType(ListTile));
      expect(find.widgetWithText(ListTile, 'Template'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Daily note'), findsOneWidget);
      await tester.tapAt(const Offset(5, 5));
      await settle(tester);

      await tester.tap(
        find.descendant(
          of: find.byType(NoteTile).first,
          matching: find.byIcon(Icons.more_vert),
        ),
      );
      await settle(tester);
      allHaveIcons(find.byType(ListTile));
      await tester.tap(find.widgetWithText(ListTile, 'Move'));
      await settle(tester);
      allHaveIcons(find.byType(ListTile));
    });

    appTest('the sort sheet saves a view that the drawer lists', (
      tester,
    ) async {
      final env = await open(tester, [const _Seed('Alpha', favorite: true)]);
      await tester.tap(find.byTooltip('More options'));
      await settle(tester);
      await tester.tap(find.text('Sort and filter'));
      await settle(tester);
      await tester.tap(find.text('Save this view'));
      await settle(tester);
      await tester.enterText(find.byType(TextField), 'My view');
      await tester.tap(find.widgetWithText(TextButton, 'Save locally'));
      await settle(tester);

      await tester.tap(find.byTooltip('Categories'));
      await settle(tester);
      expect(find.text('Saved views'), findsOneWidget);
      expect(find.text('On this device'), findsOneWidget);
      expect(find.text('My view'), findsWidgets);
      await tester.runAsync(() async {
        final stored = await const SavedViewStore().load(env.accountId);
        expect(stored.single.name, 'My view');
      });
    });

    appTest('new notes go to the category or favorites of the scope', (
      tester,
    ) async {
      final env = await open(tester, [
        const _Seed('In work', category: 'Work'),
        const _Seed('Starred', favorite: true),
      ]);
      Future<void> create() async {
        await tester.tap(find.byTooltip('New note'));
        await settle(tester);
        await tester.tap(find.widgetWithText(ListTile, 'Note'));
        await settle(tester);
      }

      final known = <String>{};
      Future<LocalNote> newest() async => (await tester.runAsync(() async {
        final rows = await env.db.select(env.db.localNotes).get();
        final fresh = rows.firstWhere(
          (n) => n.content.isEmpty && n.title.isEmpty && !known.contains(n.id),
        );
        known.add(fresh.id);
        return fresh;
      }))!;

      await tester.tap(find.byTooltip('Categories'));
      await settle(tester);
      await tester.tap(find.text('Work').last);
      await settle(tester);
      await create();
      expect((await newest()).category, 'Work');
      await tester.pageBack();
      await settle(tester);

      await tester.tap(find.byTooltip('Categories'));
      await settle(tester);
      await tester.tap(find.text('Favorites'));
      await settle(tester);
      await create();
      final fav = await newest();
      expect(fav.category, '');
      expect(fav.favorite, isTrue);
    });

    appTest('Needs attention lists a failed deletion with Retry and Undo', (
      tester,
    ) async {
      final env = await open(tester, [
        const _Seed(
          'Stuck',
          remoteId: 3,
          syncState: 'deleting',
          deleteError: 'server',
        ),
      ]);
      expect(find.text('1 deletion failed'), findsOneWidget);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Review'));
      await settle(tester);
      expect(find.text('Stuck'), findsOneWidget);
      expect(find.textContaining('Deletion failed'), findsWidgets);
      expect(find.text('Retry'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await settle(tester);
      await tester.runAsync(() async {
        final n = await env.db.select(env.db.localNotes).getSingle();
        expect(n.syncState, 'draft');
        expect(n.deleteError, isNull);
      });
    });

    appTest('empty Favorites explains starring, empty account offers create', (
      tester,
    ) async {
      await open(tester, [const _Seed('Plain')]);
      await tester.tap(find.byTooltip('Categories'));
      await settle(tester);
      await tester.tap(find.text('Favorites'));
      await settle(tester);
      expect(find.text('No favorites yet'), findsOneWidget);
      await tester.tap(find.byTooltip('Categories'));
      await settle(tester);
      await tester.tap(find.text('Shared with me'));
      await settle(tester);
      expect(find.text('Nothing shared with you'), findsOneWidget);
      await tester.tap(find.byTooltip('Categories'));
      await settle(tester);
      await tester.tap(find.text('Needs attention'));
      await settle(tester);
      expect(find.text('Nothing needs your attention'), findsOneWidget);
    });

    appTest('hardware shortcuts open search and Escape closes it', (
      tester,
    ) async {
      await open(tester, [const _Seed('Alpha')]);
      await tester.sendKeyDownEvent(
        LogicalKeyboardKey.controlLeft,
        platform: 'android',
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF, platform: 'android');
      await tester.sendKeyUpEvent(
        LogicalKeyboardKey.controlLeft,
        platform: 'android',
      );
      await settle(tester);
      expect(find.byType(TextField), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape, platform: 'android');
      await settle(tester);
      expect(find.byType(TextField), findsNothing);
    });

    appTest('on a wide window list and editor sit side by side', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await open(tester, [
        const _Seed('Alpha', content: 'first text'),
        const _Seed('Beta', content: 'second text'),
      ]);
      expect(find.text('Select a note'), findsOneWidget);
      await tester.tap(find.text('Alpha'));
      await settle(tester);
      expect(find.byType(EditorScreen), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'first text'), findsOneWidget);

      await tester.tap(find.text('Beta'));
      await settle(tester);
      await settle(tester);
      expect(find.byType(EditorScreen), findsOneWidget);
      expect(find.widgetWithText(TextField, 'second text'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'first text'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    appTest('narrowing the window keeps the open note', (tester) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await open(tester, [const _Seed('Alpha', content: 'first text')]);
      await tester.tap(find.text('Alpha'));
      await settle(tester);
      final field = find.widgetWithText(TextField, 'first text');
      await tester.enterText(field, 'edited while wide');
      tester.view.physicalSize = const Size(411, 800);
      await settle(tester);
      expect(
        find.widgetWithText(TextField, 'edited while wide'),
        findsOneWidget,
      );
      expect(find.byType(EditorScreen), findsOneWidget);
    });
  });
}

/// Lets real async work and timers run between frames.
Future<void> settle(WidgetTester tester) => tester.runAsync(() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await tester.pump(const Duration(milliseconds: 100));
  }
});
