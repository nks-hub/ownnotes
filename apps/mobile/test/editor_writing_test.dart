import 'dart:convert';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:notes_protocol/notes_protocol.dart';
import 'package:notes_store/notes_store.dart';
import 'package:nextcloudnotes/data/runtime.dart';
import 'package:nextcloudnotes/design/design.dart';
import 'package:nextcloudnotes/features/editor.dart';
import 'package:nextcloudnotes/features/editor/document_header.dart';
import 'package:nextcloudnotes/features/editor/preview.dart';
import 'package:nextcloudnotes/features/editor/share_sheet.dart';
import 'package:nextcloudnotes/features/editor/suggestion_source.dart';
import 'package:nextcloudnotes/features/templates/templates.dart';
import 'package:nextcloudnotes/l10n/app_localizations.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

class _Vault implements CredentialVault {
  final entries = <String, String>{};
  @override
  Future<void> write(String reference, String password) async =>
      entries[reference] = password;
  @override
  Future<String?> read(String reference) async => entries[reference];
  @override
  Future<void> delete(String reference) async => entries.remove(reference);
  @override
  Future<Set<String>> references() async => entries.keys.toSet();
}

class _FakeSource implements SuggestionSource {
  _FakeSource({this.failing = false});
  final bool failing;
  final queries = <String>[];
  @override
  Future<List<MentionCandidate>> users(String query) async {
    queries.add(query);
    if (failing) throw StateError('offline');
    return query.startsWith('ja')
        ? [
            const MentionCandidate(id: 'jan', label: 'Jan Novák'),
            const MentionCandidate(id: 'jana', label: 'Jana Nováková'),
          ]
        : const [];
  }

  @override
  Future<List<ReferenceProvider>> providers() async => const [
    ReferenceProvider(id: 'files', title: 'Files', searchId: 'files'),
  ];

  @override
  Future<List<ReferenceResult>> search(ReferenceProvider p, String term) async => [
    ReferenceResult(
      title: 'Plan [2026]',
      url: Uri.parse('https://cloud.test/f/9'),
      subline: 'in Notes',
    ),
  ];

  @override
  void close() {}
}

Future<void> _settle(WidgetTester tester, [int rounds = 12]) =>
    tester.runAsync(() async {
      for (var i = 0; i < rounds; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump(const Duration(milliseconds: 100));
      }
    });

Finder get _source => find.byWidgetPredicate((w) => w is TextField && w.expands);

TextEditingController _controller(WidgetTester tester) =>
    tester.widget<TextField>(_source).controller!;

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

http.Response _ocs(Object? data) =>
    _json({'ocs': {'meta': {'statuscode': 200}, 'data': data}});

Future<(AppRuntime, LocalNote)> _setup(
  WidgetTester tester, {
  String content = '',
  String title = 'Doc',
  String category = '',
  bool readonly = false,
  int? remoteId,
  String kind = 'note',
  String syncState = 'draft',
  Future<http.Response> Function(http.Request)? handler,
}) async {
  final runtime = (await tester.runAsync(
    () async => AppRuntime(
      NotesDatabase(NativeDatabase.memory()),
      _Vault(),
      transport: () => MockClient(
        handler ??
            (r) async => r.url.pathSegments.last == 'notes' ? _json([]) : _json({}),
      ),
    ),
  ))!;
  addTearDown(runtime.close);
  final note = (await tester.runAsync(() async {
    await runtime.accounts.add(
      LoginCredentials(
        server: ServerBase.parse('https://cloud.test'),
        loginName: 'test',
        appPassword: 'secret',
      ),
    );
    final db = runtime.database;
    final account = (await db.watchAccounts().first).single;
    await db
        .into(db.localNotes)
        .insert(
          LocalNotesCompanion.insert(
            id: 'n1',
            accountId: account.id,
            title: title,
            content: content,
            updatedAt: 1,
            category: Value(category),
            readonly: Value(readonly),
            remoteId: Value(remoteId),
            etag: Value(remoteId == null ? null : 'e1'),
            kind: Value(kind),
            syncState: Value(syncState),
          ),
        );
    return (await db.note(account.id, 'n1'))!;
  }))!;
  return (runtime, note);
}

Future<void> _open(
  WidgetTester tester,
  AppRuntime runtime,
  LocalNote note, {
  List<Override> overrides = const [],
  AttachHandler? onAttach,
  Size size = const Size(400, 800),
  Locale? locale,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [runtimeProvider.overrideWithValue(runtime), ...overrides],
      child: MaterialApp(
        theme: OwnTheme.light(),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: EditorScreen(note: note, onAttach: onAttach),
      ),
    ),
  );
  await _settle(tester, 3);
}

Future<void> _close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pumpAndSettle();
}

Override _suggestions(_FakeSource source) =>
    suggestionSourceFactoryProvider.overrideWithValue((_) async => source);

void main() {
  setUpAll(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  group('typing and styling', () {
    testWidgets('headings keep the editing value, selection and composition', (
      tester,
    ) async {
      final (runtime, note) = await _setup(tester);
      await _open(tester, runtime, note);
      await tester.tap(_source);
      await tester.pump();
      for (final text in ['#', '# ', '# T', '## Tí', '## Tít']) {
        await tester.enterText(_source, text);
        await tester.pump();
        expect(_controller(tester).text, text);
        expect(_controller(tester).selection, TextSelection.collapsed(offset: text.length));
      }
      // A word still being composed keeps its range through restyling.
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '## Tít háč',
          selection: TextSelection.collapsed(offset: 10),
          composing: TextRange(start: 6, end: 10),
        ),
      );
      await tester.pump();
      final composing = _controller(tester).value;
      expect(composing.composing, const TextRange(start: 6, end: 10));
      // A window resize and a rebuild change nothing in the value.
      tester.view.physicalSize = const Size(500, 700);
      await tester.pump();
      tester.view.physicalSize = const Size(400, 800);
      await tester.pump();
      expect(_controller(tester).value, composing);
      expect(tester.widget<TextField>(_source).focusNode!.hasFocus, isTrue);
      await _close(tester);
    });

    testWidgets('undo survives styling and resize, commands are single steps', (
      tester,
    ) async {
      final (runtime, note) = await _setup(tester);
      await _open(tester, runtime, note);
      await tester.tap(_source);
      await tester.enterText(_source, '# word');
      await tester.pump();
      _controller(tester).selection = const TextSelection(baseOffset: 2, extentOffset: 6);
      await tester.pump();
      await tester.tap(find.byTooltip('Format'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.format_bold), findsOneWidget);
      await tester.tap(find.text('Bold'));
      await tester.pumpAndSettle();
      expect(_controller(tester).text, '# **word**');
      tester.view.physicalSize = const Size(600, 500);
      await tester.pump();
      tester.view.physicalSize = const Size(400, 800);
      await tester.pump();
      await tester.tap(find.byTooltip('Undo'));
      await tester.pump();
      expect(_controller(tester).text, '# word');
      await tester.tap(find.byTooltip('Redo'));
      await tester.pump();
      expect(_controller(tester).text, '# **word**');
      await _close(tester);
    });

    testWidgets('Enter continues a list and an empty item leaves it', (
      tester,
    ) async {
      final (runtime, note) = await _setup(tester);
      await _open(tester, runtime, note);
      await tester.tap(_source);
      await tester.enterText(_source, '- [ ] milk');
      await tester.pump();
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '- [ ] milk\n',
          selection: TextSelection.collapsed(offset: 11),
        ),
      );
      await tester.pump();
      expect(_controller(tester).text, '- [ ] milk\n- [ ] ');
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '- [ ] milk\n- [ ] \n',
          selection: TextSelection.collapsed(offset: 18),
        ),
      );
      await tester.pump();
      expect(_controller(tester).text, '- [ ] milk\n');
      await _close(tester);
    });

    testWidgets('the Task button and the Attach menu', (tester) async {
      final (runtime, note) = await _setup(tester, content: 'buy milk');
      final picked = <AttachKind>[];
      await _open(tester, runtime, note, onAttach: picked.add);
      await tester.tap(_source);
      await tester.pump();
      _controller(tester).selection = const TextSelection.collapsed(offset: 3);
      await tester.tap(find.byTooltip('Task'));
      await tester.pump();
      expect(_controller(tester).text, '- [ ] buy milk');
      await tester.tap(find.byTooltip('Attach'));
      await tester.pumpAndSettle();
      for (final label in ['Photo', 'Camera', 'File', 'Voice']) {
        expect(find.text(label), findsOneWidget);
      }
      await tester.tap(find.text('Camera'));
      await tester.pumpAndSettle();
      expect(picked, [AttachKind.camera]);
      await _close(tester);
    });

    testWidgets('Attach rows are disabled until a handler exists', (tester) async {
      final (runtime, note) = await _setup(tester);
      await _open(tester, runtime, note);
      await tester.tap(find.byTooltip('Attach'));
      await tester.pumpAndSettle();
      final item = tester.widget<PopupMenuItem<AttachKind>>(
        find.byWidgetPredicate((w) => w is PopupMenuItem<AttachKind>).first,
      );
      expect(item.enabled, isFalse);
      await _close(tester);
    });
  });

  group('top bar and header', () {
    testWidgets('three icon actions, overflow rows all have icons', (tester) async {
      final (runtime, note) = await _setup(tester, title: 'Meeting', category: 'Work/Planning');
      await _open(tester, runtime, note);
      expect(find.byTooltip('Preview'), findsOneWidget);
      expect(find.byTooltip('Share'), findsOneWidget);
      expect(find.byTooltip('More options'), findsOneWidget);
      // Title and breadcrumb are typography, not fields.
      expect(find.text('Work / Planning'), findsOneWidget);
      await tester.tap(find.byTooltip('More options'));
      await tester.pumpAndSettle();
      for (final label in [
        'Details',
        'Favorite',
        'Find in note',
        'Open checklist',
        'Attachments',
        'History and recovery',
        'Export',
        'Delete',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      final rows = find.byWidgetPredicate((w) => w is PopupMenuItem);
      expect(rows, findsNWidgets(8));
      expect(find.descendant(of: rows, matching: find.byType(Icon)), findsNWidgets(8));
      await _close(tester);
    });

    testWidgets('the header gives way to the text while the keyboard is up', (
      tester,
    ) async {
      final (runtime, note) = await _setup(tester, title: 'Meeting');
      await _open(tester, runtime, note);
      await tester.tap(_source);
      await tester.pump();
      final focus = tester.widget<TextField>(_source).focusNode!;
      final before = tester.getSize(_source).height;
      expect(find.text('Saved locally'), findsOneWidget);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pump();
      await tester.pump();
      expect(tester.widget<TextField>(_source).focusNode!, same(focus));
      expect(focus.hasFocus, isTrue);
      // The same field instance, bigger: header and routine status collapsed.
      expect(tester.getSize(_source).height, greaterThan(before - 300));
      expect(find.text('Saved locally'), findsNothing);
      expect(find.byTooltip('Preview'), findsOneWidget);
      expect(find.byTooltip('Share'), findsOneWidget);
      expect(find.byTooltip('More options'), findsOneWidget);
      tester.view.resetViewInsets();
      await tester.pump();
      expect(find.text('Saved locally'), findsOneWidget);
      await _close(tester);
    });

    testWidgets('tapping the title opens Details with that field focused', (
      tester,
    ) async {
      final (runtime, note) = await _setup(tester, title: 'Meeting');
      await _open(tester, runtime, note);
      await tester.tap(
        find.descendant(of: find.byType(DocumentHeader), matching: find.text('Meeting')),
      );
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Meeting'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'Meeting'), 'Renamed');
      await tester.pump(const Duration(milliseconds: 500));
      await _close(tester);
      final saved = (await tester.runAsync(() => runtime.database.note(note.accountId, note.id)))!;
      expect(saved.title, 'Renamed');
    });
  });

  group('suggestions', () {
    testWidgets('@ inserts a Text mention and the insertion is one undo step', (
      tester,
    ) async {
      final source = _FakeSource();
      final (runtime, note) = await _setup(tester);
      await _open(tester, runtime, note, overrides: [_suggestions(source)]);
      await tester.tap(_source);
      await tester.enterText(_source, 'hi @ja');
      await tester.pump(const Duration(milliseconds: 400));
      await _settle(tester, 2);
      expect(find.text('Jan Novák'), findsOneWidget);
      expect(find.text('Jana Nováková'), findsOneWidget);
      expect(source.queries.last, 'ja');
      await tester.tap(find.text('Jan Novák'));
      await tester.pump();
      expect(_controller(tester).text, 'hi @[Jan Novák](mention://user/jan) ');
      expect(find.text('Jan Novák'), findsNothing);
      await tester.tap(find.byTooltip('Undo'));
      await tester.pump();
      expect(_controller(tester).text, 'hi @ja');
      await _close(tester);
    });

    testWidgets('Escape dismisses and the typed text stays', (tester) async {
      final (runtime, note) = await _setup(tester);
      await _open(tester, runtime, note, overrides: [_suggestions(_FakeSource())]);
      await tester.tap(_source);
      await tester.enterText(_source, 'sun :smi');
      await tester.pump();
      expect(find.text('smiley'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.text('smiley'), findsNothing);
      expect(_controller(tester).text, 'sun :smi');
      // Typing on does not reopen the dismissed trigger.
      await tester.enterText(_source, 'sun :smil');
      await tester.pump();
      expect(find.text('smiley'), findsNothing);
      await _close(tester);
    });

    testWidgets('arrow keys select and Enter accepts an emoji offline', (
      tester,
    ) async {
      final (runtime, note) = await _setup(tester);
      await _open(tester, runtime, note, overrides: [_suggestions(_FakeSource(failing: true))]);
      await tester.tap(_source);
      await tester.enterText(_source, ':milk');
      await tester.pump();
      expect(find.text('milk'), findsWidgets);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(_controller(tester).text, '🥛');
      await _close(tester);
    });

    testWidgets('a failing server fills the popup, writing goes on', (
      tester,
    ) async {
      final (runtime, note) = await _setup(tester);
      await _open(tester, runtime, note, overrides: [_suggestions(_FakeSource(failing: true))]);
      await tester.tap(_source);
      await tester.enterText(_source, '@ja');
      await tester.pump(const Duration(milliseconds: 400));
      await _settle(tester, 2);
      expect(find.textContaining('Suggestions are not available'), findsOneWidget);
      await tester.enterText(_source, '@ja more text');
      await tester.pump();
      expect(_controller(tester).text, '@ja more text');
      expect(find.textContaining('Suggestions are not available'), findsNothing);
      await _close(tester);
    });

    testWidgets('/ offers local commands and server providers as plain links', (
      tester,
    ) async {
      final (runtime, note) = await _setup(tester);
      await _open(tester, runtime, note, overrides: [_suggestions(_FakeSource())]);
      await tester.tap(_source);
      await tester.enterText(_source, '/head');
      await tester.pump();
      await tester.tap(find.text('Heading 1'));
      await tester.pump();
      expect(_controller(tester).text, '# ');
      await tester.enterText(_source, '\n/fil');
      await tester.pump();
      await _settle(tester, 2);
      expect(find.text('Files'), findsOneWidget);
      await tester.tap(find.text('Files'));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      await _settle(tester, 8);
      await tester.tap(find.textContaining('Plan'));
      await tester.pumpAndSettle();
      expect(_controller(tester).text, '\n[Plan 2026](https://cloud.test/f/9)');
      await _close(tester);
    });

    testWidgets('Insert menu opens the mention and emoji lists', (tester) async {
      final (runtime, note) = await _setup(tester, content: 'word');
      await _open(tester, runtime, note, overrides: [_suggestions(_FakeSource())]);
      await tester.tap(_source);
      await tester.pump();
      await tester.tap(find.byTooltip('Insert'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Emoji'));
      await tester.pumpAndSettle();
      expect(_controller(tester).text, 'word :');
      expect(find.byType(ListView), findsWidgets);
      expect(find.textContaining('smile', findRichText: true), findsWidgets);
      await _close(tester);
    });
  });

  group('preview', () {
    const rich =
        '# Head\n\nHello @[Jan Novák](mention://user/jan) there\n\n'
        '::: warn\ncareful now\n:::\n\n'
        '| name | amount |\n| --- | --- |\n| milk | 2 |\n\n'
        '<details>\n<summary>More</summary>\n\nhidden words\n\n</details>\n\n'
        'See [the plan](.attachments.7/plan.pdf) and [site](https://x.test)\n\n'
        '- [ ] task one';

    testWidgets('mentions, callouts, tables, details, attachments, tasks', (
      tester,
    ) async {
      final (runtime, note) = await _setup(tester, content: rich);
      await _open(tester, runtime, note);
      await tester.tap(find.byTooltip('Preview'));
      await _settle(tester, 4);
      expect(find.byType(MentionChip), findsOneWidget);
      expect(find.text('Jan Novák'), findsOneWidget);
      expect(find.textContaining('Warning'), findsOneWidget);
      expect(find.textContaining('careful now', findRichText: true), findsOneWidget);
      expect(find.byType(Table), findsOneWidget);
      expect(
        find.ancestor(
          of: find.byType(Table),
          matching: find.byWidgetPredicate(
            (w) => w is SingleChildScrollView && w.scrollDirection == Axis.horizontal,
          ),
        ),
        findsOneWidget,
      );
      expect(find.text('milk', findRichText: true), findsOneWidget);
      expect(find.byType(AttachmentChip), findsOneWidget);
      expect(find.textContaining('plan.pdf'), findsOneWidget);
      expect(find.byType(Checkbox), findsOneWidget);
      // Details start closed and open on a tap without leaving the preview.
      expect(find.text('More'), findsOneWidget);
      expect(find.textContaining('hidden words', findRichText: true), findsNothing);
      await tester.ensureVisible(find.text('More'));
      await tester.tap(find.text('More'));
      await _settle(tester, 2);
      expect(find.textContaining('hidden words', findRichText: true), findsOneWidget);
      expect(find.byTooltip('Edit source'), findsOneWidget);
      await _close(tester);
    });

    testWidgets('repeated blocks map to their own source occurrence', (
      tester,
    ) async {
      const text = 'same\n\nsame\n\nsame\n\n- milk\n- milk\n- milk';
      final (runtime, note) = await _setup(tester, content: text);
      await _open(tester, runtime, note);
      await tester.tap(find.byTooltip('Preview'));
      await _settle(tester, 4);
      final same = find.text('same', findRichText: true);
      expect(same, findsNWidgets(3));
      await tester.tap(same.at(2));
      await _settle(tester, 4);
      expect(_controller(tester).selection.baseOffset, 12);
      await tester.tap(find.byTooltip('Preview'));
      await _settle(tester, 4);
      final milk = find.text('milk', findRichText: true);
      expect(milk, findsNWidgets(3));
      await tester.tap(milk.at(1));
      await _settle(tester, 4);
      expect(_controller(tester).selection.baseOffset, text.indexOf('milk', text.indexOf('milk') + 1));
      await _close(tester);
    });

    testWidgets('a duplicate task label toggles the tapped one only', (
      tester,
    ) async {
      const text = '- [ ] milk\n\ntext\n\n- [ ] milk';
      final (runtime, note) = await _setup(tester, content: text);
      await _open(tester, runtime, note);
      await tester.tap(find.byTooltip('Preview'));
      await _settle(tester, 4);
      await tester.tap(find.byType(Checkbox).last);
      await _settle(tester, 4);
      expect(tester.widgetList<Checkbox>(find.byType(Checkbox)).map((c) => c.value), [false, true]);
      await tester.tap(find.byTooltip('Edit source'));
      await _settle(tester, 4);
      expect(_controller(tester).text, '- [ ] milk\n\ntext\n\n- [x] milk');
      await _close(tester);
    });

    testWidgets('Edit this section is offered to assistive technology', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final (runtime, note) = await _setup(tester, content: 'first\n\nsecond');
      await _open(tester, runtime, note);
      await tester.tap(find.byTooltip('Preview'));
      await _settle(tester, 4);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              (w.properties.customSemanticsActions?.keys.any(
                    (a) => a.label == 'Edit this section',
                  ) ??
                  false),
        ),
        findsNWidgets(2),
      );
      handle.dispose();
      await _close(tester);
    });
  });

  group('checklist mode', () {
    const shop = '# Shop\n\nProse stays.\n\n- [ ] milk\n- [x] bread\n- [ ] eggs\n\nEnd.';

    Future<void> openChecklist(WidgetTester tester) async {
      await tester.tap(find.byTooltip('More options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open checklist'));
      await tester.pumpAndSettle();
    }

    testWidgets('tick, quick add and clear completed keep the prose', (
      tester,
    ) async {
      final (runtime, note) = await _setup(tester, content: shop);
      await _open(tester, runtime, note);
      await openChecklist(tester);
      expect(find.text('1 of 3 tasks done'), findsOneWidget);
      expect(find.text('Completed (1)'), findsOneWidget);
      expect(find.text('Prose stays.'), findsOneWidget);
      // Tick milk.
      await tester.tap(find.text('milk'));
      await tester.pumpAndSettle();
      expect(find.text('2 of 3 tasks done'), findsOneWidget);
      expect(find.text('Completed (2)'), findsOneWidget);
      // Quick add.
      await tester.enterText(find.widgetWithText(TextField, 'Add item'), 'cheese');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text('cheese'), findsOneWidget);
      // Clear completed, then undo it.
      await tester.ensureVisible(find.text('Clear completed items'));
      await tester.tap(find.text('Clear completed items'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Remove 2 completed items'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Clear completed items'));
      await tester.pumpAndSettle();
      expect(find.text('milk'), findsNothing);
      expect(find.text('2 items removed'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(find.text('milk'), findsOneWidget);
      // Back in Markdown the prose and the rest are intact.
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(
        _controller(tester).text,
        '# Shop\n\nProse stays.\n\n- [x] milk\n- [x] bread\n- [ ] eggs\n- [ ] cheese\n\nEnd.'
            .replaceFirst('- [ ] eggs\n- [ ] cheese', '- [ ] eggs\n- [ ] cheese'),
      );
      await _close(tester);
    });

    testWidgets('Move down changes only the order of the blocks', (tester) async {
      final (runtime, note) = await _setup(
        tester,
        content: '- [ ] a\n  detail of a\n- [ ] b\n- [ ] c',
      );
      await _open(tester, runtime, note);
      await openChecklist(tester);
      await tester.tap(find.byTooltip('Item options').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Move down'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(_controller(tester).text, '- [ ] b\n- [ ] a\n  detail of a\n- [ ] c');
      await _close(tester);
    });

    testWidgets('a read-only note offers no checklist edits', (tester) async {
      final (runtime, note) = await _setup(tester, content: shop, readonly: true);
      await _open(tester, runtime, note);
      await openChecklist(tester);
      expect(find.widgetWithText(TextField, 'Add item'), findsNothing);
      expect(find.byTooltip('Item options'), findsNothing);
      await _close(tester);
    });

    testWidgets('checklist mode is never the way a note opens', (tester) async {
      final (runtime, note) = await _setup(tester, content: shop);
      await _open(tester, runtime, note);
      expect(_source, findsOneWidget);
      expect(find.text('Add item'), findsNothing);
      await _close(tester);
    });
  });

  group('sharing', () {
    Future<http.Response> server(http.Request r, List<String> log, {int shareStatus = 200}) async {
      log.add('${r.method} ${r.url.path}${r.url.query.isEmpty ? '' : '?${r.url.query}'}');
      final p = r.url.path;
      if (p.endsWith('/api/v1/notes') && r.method == 'GET') return _json([]);
      if (p.endsWith('/api/v1/notes') && r.method == 'POST') {
        return _json({
          'id': 55,
          'etag': 'e1',
          'title': 'Doc',
          'content': 'text',
          'category': '',
          'favorite': false,
          'readonly': false,
          'modified': 5,
          'internalPath': '/Notes/Doc.md',
        });
      }
      if (p.contains('/api/v1/notes/')) {
        return _json({
          'id': int.parse(p.split('/').last),
          'etag': 'e1',
          'title': 'Doc',
          'content': 'text',
          'category': '',
          'favorite': false,
          'readonly': false,
          'modified': 5,
          'internalPath': '/Notes/Doc.md',
        });
      }
      if (p.endsWith('/sharees')) {
        return _ocs({
          'users': [
            {'label': 'Jan Novák', 'value': {'shareType': 0, 'shareWith': 'jan'}},
          ],
        });
      }
      if (p.endsWith('/shares') && r.method == 'GET') {
        return _ocs(shared
            .map((s) => {'id': s.$1, 'share_type': 0, 'share_with': s.$2, 'permissions': s.$3, 'path': '/Notes/Doc.md'})
            .toList());
      }
      if (p.endsWith('/shares') && r.method == 'POST') {
        if (shareStatus != 200) return _json({}, shareStatus);
        final form = Uri.splitQueryString(r.body);
        shared.add(('31', form['shareWith']!, int.parse(form['permissions']!)));
        return _ocs({'id': 31, 'share_with': form['shareWith'], 'permissions': int.parse(form['permissions']!), 'path': '/Notes/Doc.md'});
      }
      if (r.method == 'DELETE') {
        shared.clear();
        return _ocs([]);
      }
      return _json({});
    }

    testWidgets('send a copy works offline as text and as a file', (tester) async {
      final sent = <(String, String, bool)>[];
      final (runtime, note) = await _setup(tester, title: 'Plan', content: 'body', remoteId: 7);
      await _open(
        tester,
        runtime,
        note,
        overrides: [
          copySenderProvider.overrideWithValue(
            ({required title, required text, required asFile}) async => sent.add((title, text, asFile)),
          ),
        ],
      );
      await tester.tap(find.byTooltip('Share'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send as text'));
      await tester.tap(find.text('Send as Markdown file'));
      await tester.pump();
      expect(sent, [('Plan', 'body', false), ('Plan', 'body', true)]);
      expect(markdownFileName('a/b: c?'), 'a b c.md');
      expect(markdownFileName('  '), 'note.md');
      await _close(tester);
    });

    testWidgets('a never uploaded note uploads first, then can be shared', (tester) async {
      final log = <String>[];
      shared.clear();
      final (runtime, note) = await _setup(
        tester,
        content: 'text',
        handler: (r) => server(r, log),
      );
      await _open(tester, runtime, note);
      await tester.tap(find.byTooltip('Share'));
      await tester.pumpAndSettle();
      expect(find.textContaining('not on the server yet'), findsOneWidget);
      expect(log.where((l) => l.startsWith('POST') && l.contains('/shares')), isEmpty);
      await tester.tap(find.text('Upload and continue'));
      await _settle(tester, 25);
      await tester.pumpAndSettle();
      expect(log.any((l) => l.startsWith('POST') && l.endsWith('/api/v1/notes')), isTrue);
      expect(find.widgetWithText(TextField, 'Search people'), findsOneWidget);
      await _close(tester);
    });

    testWidgets('share as viewer, see the list, remove access', (tester) async {
      final log = <String>[];
      shared.clear();
      final (runtime, note) = await _setup(
        tester,
        content: 'text',
        remoteId: 7,
        syncState: 'clean',
        handler: (r) => server(r, log),
      );
      await _open(tester, runtime, note);
      await tester.tap(find.byTooltip('Share'));
      await _settle(tester, 6);
      await tester.pumpAndSettle();
      expect(find.text('Not shared with anyone yet.'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'Search people'), 'ja');
      await tester.pump(const Duration(milliseconds: 400));
      await _settle(tester, 4);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Jan Novák'));
      await tester.pumpAndSettle();
      // Can view is the default.
      expect(find.text('Can view'), findsOneWidget);
      await tester.tap(find.text('Share with Jan Novák'));
      await _settle(tester, 6);
      await tester.pumpAndSettle();
      final post = log.lastWhere((l) => l.startsWith('POST') && l.contains('/shares'));
      expect(post, isNotEmpty);
      expect(find.text('jan'), findsOneWidget);
      expect(find.text('Can view'), findsOneWidget);
      await tester.tap(find.byTooltip('Remove access'));
      await _settle(tester, 6);
      await tester.pumpAndSettle();
      expect(find.text('Not shared with anyone yet.'), findsOneWidget);
      expect(log.any((l) => l.startsWith('DELETE')), isTrue);
      await _close(tester);
    });

    testWidgets('a failed share is shown with Retry and nothing else breaks', (tester) async {
      final log = <String>[];
      shared.clear();
      var failing = true;
      final (runtime, note) = await _setup(
        tester,
        content: 'text',
        remoteId: 7,
        syncState: 'clean',
        handler: (r) => server(r, log, shareStatus: failing ? 500 : 200),
      );
      await _open(tester, runtime, note);
      await tester.tap(find.byTooltip('Share'));
      await _settle(tester, 6);
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Search people'), 'ja');
      await tester.pump(const Duration(milliseconds: 400));
      await _settle(tester, 4);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Jan Novák'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Share with Jan Novák'));
      await _settle(tester, 6);
      await tester.pumpAndSettle();
      expect(find.textContaining('This did not work'), findsOneWidget);
      failing = false;
      await tester.tap(find.text('Retry'));
      await _settle(tester, 6);
      await tester.pumpAndSettle();
      expect(find.textContaining('This did not work'), findsNothing);
      expect(find.text('jan'), findsOneWidget);
      await _close(tester);
    });

    testWidgets('a note shared with me cannot be shared further', (tester) async {
      final (runtime, note) = await _setup(tester, content: 'x', remoteId: 9, kind: 'shared');
      await _open(tester, runtime, note);
      await tester.tap(find.byTooltip('Share'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Only its owner can share it further'), findsOneWidget);
      await _close(tester);
    });

    testWidgets('attachments get a warning in the share sheet', (tester) async {
      final log = <String>[];
      shared.clear();
      final (runtime, note) = await _setup(
        tester,
        content: '![p](.attachments.7/a.png)',
        remoteId: 7,
        syncState: 'clean',
        handler: (r) => server(r, log),
      );
      await _open(tester, runtime, note);
      await tester.tap(find.byTooltip('Share'));
      await _settle(tester, 4);
      await tester.pumpAndSettle();
      expect(find.textContaining('may not be able to open them'), findsOneWidget);
      await _close(tester);
    });
  });

  group('saving', () {
    testWidgets('a local save failure is reported and listed under attention', (
      tester,
    ) async {
      final (runtime, note) = await _setup(tester, content: 'x', syncState: 'unreadable');
      await _open(tester, runtime, note);
      await tester.tap(_source);
      await tester.enterText(_source, 'typed on top');
      await tester.pump(const Duration(milliseconds: 500));
      await _settle(tester, 3);
      expect(find.text('Could not save on this device'), findsWidgets);
      expect(find.textContaining('could not hand out this note'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Copy Markdown'), findsOneWidget);
      expect(find.text('Export draft'), findsOneWidget);
      final items = await tester.runAsync(
        () => runtime.attention.watch(note.accountId).firstWhere(
          (list) => list.any((i) => i.kind == AttentionKind.saveFailure),
        ).timeout(const Duration(seconds: 5)),
      );
      expect(items!.any((i) => i.reason == 'note_unreadable'), isTrue);
      // The typed text is still in the editor.
      expect(_controller(tester).text, 'typed on top');
      await _close(tester);
    });
  });

  group('templates and daily notes', () {
    test('placeholders become ordinary text', () {
      final when = DateTime(2026, 10, 20, 7, 5);
      expect(
        expandTemplate('# {{date}} {{time}}\n{{title}}', when, title: 'T'),
        '# 2026-10-20 07:05\nT',
      );
      expect(planDailyNote(const DailyNoteConfig(category: 'Daily'), when).title, '2026-10-20');
      expect(
        planDailyNote(const DailyNoteConfig(titlePattern: 'EEE d.M.'), when).title,
        'Tue 20.10.',
      );
    });

    test('store round trip and bad data', () async {
      const store = TemplateStore();
      expect(await store.templates(), isEmpty);
      await store.saveTemplates(const [
        NoteTemplate(id: 'a', name: 'Meeting', content: '# {{title}}', category: 'Work'),
      ]);
      final list = await store.templates();
      expect(list.single.name, 'Meeting');
      expect(list.single.category, 'Work');
      await store.saveDaily(const DailyNoteConfig(category: 'Daily', templateId: 'a'));
      expect((await store.daily()).templateId, 'a');
    });

    Future<(AppRuntime, String)> runtimeWithAccount() async {
      final runtime = AppRuntime(NotesDatabase(NativeDatabase.memory()), _Vault());
      await runtime.accounts.add(
        LoginCredentials(
          server: ServerBase.parse('https://cloud.test'),
          loginName: 'test',
          appPassword: 'secret',
        ),
      );
      final account = (await runtime.database.watchAccounts().first).single;
      return (runtime, account.id);
    }

    test('createFromTemplate makes a draft in the chosen category', () async {
      final (runtime, account) = await runtimeWithAccount();
      final id = await createFromTemplate(
        runtime,
        account,
        const NoteTemplate(id: 't', name: 'Meet', title: 'Meet {{date}}', content: '- [ ] {{title}}', category: 'Work'),
        now: DateTime(2026, 1, 2),
      );
      final note = (await runtime.database.note(account, id))!;
      expect(note.title, 'Meet 2026-01-02');
      expect(note.content, '- [ ] Meet 2026-01-02');
      expect(note.category, 'Work');
      final moved = await createFromTemplate(
        runtime,
        account,
        const NoteTemplate(id: 't', name: 'Meet'),
        category: 'Elsewhere',
      );
      expect((await runtime.database.note(account, moved))!.category, 'Elsewhere');
      await runtime.close();
    });

    test('the daily note is created once per title and category', () async {
      final (runtime, account) = await runtimeWithAccount();
      const config = DailyNoteConfig(category: 'Daily');
      final when = DateTime(2026, 5, 6);
      final first = await createDailyNote(
        runtime,
        account,
        config: config,
        now: when,
        template: const NoteTemplate(id: 't', name: 'D', content: '## {{date}}'),
      );
      expect(first.created, isTrue);
      expect(first.plan.title, '2026-05-06');
      final note = (await runtime.database.note(account, first.noteId))!;
      expect(note.content, '## 2026-05-06');
      expect(note.category, 'Daily');
      final again = await createDailyNote(runtime, account, config: config, now: when);
      expect(again.created, isFalse);
      expect(again.noteId, first.noteId);
      final next = await createDailyNote(runtime, account, config: config, now: DateTime(2026, 5, 7));
      expect(next.created, isTrue);
      await runtime.close();
    });
  });
}

/// Shares known to the fake server of the sharing tests: id, user, permissions.
final shared = <(String, String, int)>[];
