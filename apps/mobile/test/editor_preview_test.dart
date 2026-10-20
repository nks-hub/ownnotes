import 'dart:convert';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:notes_protocol/notes_protocol.dart';
import 'package:notes_store/notes_store.dart';
import 'package:nextcloudnotes/data/runtime.dart';
import 'package:nextcloudnotes/features/editor.dart';
import 'package:nextcloudnotes/main.dart';

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

const _content = '# Title\n\nfirst line\n\nsecond **banana** line\n\n- [ ] task';

Future<void> _openPreview(WidgetTester tester, {bool readonly = false}) async {
  await _openEditor(tester, readonly: readonly);
  await tester.tap(find.byTooltip('Preview'));
  await _settle(tester);
}

/// Opens the only note; it starts in the raw text.
Future<AppRuntime> _openEditor(
  WidgetTester tester, {
  bool readonly = false,
}) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final note = {
    'id': 7,
    'etag': 'etag1',
    'title': 'Doc',
    'content': _content,
    'category': '',
    'favorite': false,
    'readonly': readonly,
    'modified': 10,
  };
  final runtime = (await tester.runAsync(
    () async => AppRuntime(
      NotesDatabase(NativeDatabase.memory()),
      _Vault(),
      transport: () => MockClient(
        (r) async => http.Response(
          jsonEncode(r.url.pathSegments.last == 'notes' ? [note] : note),
          200,
          headers: {'content-type': 'application/json'},
        ),
      ),
    ),
  ))!;
  addTearDown(runtime.close);
  await tester.runAsync(
    () => runtime.accounts.add(
      LoginCredentials(
        server: ServerBase.parse('https://cloud.test'),
        loginName: 'test',
        appPassword: 'secret',
      ),
    ),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [runtimeProvider.overrideWithValue(runtime)],
      child: const OwnNotesApp(),
    ),
  );
  await _settle(tester);
  await tester.tap(find.text('Doc'));
  await _settle(tester);
  return runtime;
}

Future<void> _settle(WidgetTester tester) => tester.runAsync(() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await tester.pump(const Duration(milliseconds: 100));
  }
});

Finder get _sourceField =>
    find.byWidgetPredicate((w) => w is TextField && w.expands);

Future<LocalNote> currentRow(AppRuntime runtime) async {
  final db = runtime.database;
  final account = (await db.watchAccounts().first).single;
  return (await db.watchNotes(account.id).first).single;
}

void main() {
  test('highlighter styles headings, bold, code and tasks', () {
    const text = '## Head\n**b** and `c`\n- [x] done\n```\n**no**\n```';
    final spans = markdownSpans(
      text,
      const TextStyle(fontSize: 16),
      dim: Colors.grey,
      accent: Colors.blue,
    );
    expect(spans.map((s) => s.text).join(), text);
    TextSpan span(String t) => spans.firstWhere((s) => s.text == t);
    expect(span('Head').style!.fontWeight, FontWeight.bold);
    expect(span('Head').style!.fontSize, greaterThan(16));
    expect(span('##').style!.color, Colors.grey);
    expect(span('b').style!.fontWeight, FontWeight.bold);
    expect(span('c').style!.fontFamily, 'monospace');
    expect(span('[x]').style!.color, Colors.blue);
    expect(span('done').style!.decoration, TextDecoration.lineThrough);
    expect(span('**no**').style!.fontFamily, 'monospace');
  });

  test('source offset follows the tapped word', () {
    expect(sourceOffsetFor(_content, 'banana', 'banana line'), 30);
    expect(sourceOffsetFor(_content, 'first', 'first line'), 9);
  });

  test('task marks follow the renderer, not the look of a line', () {
    const text =
        'intro\n\n    - [ ] indented code\n\n- [ ] a\n\n> - [ ] quoted\n\n'
        '````\n```\n- [ ] fenced\n````\n\n~~~\n- [ ] tilde\n~~~\n- [x] last';
    final marks = taskMarks(text);
    expect(marks.map((i) => text.substring(i - 1, i + 2)), [
      '[ ]',
      '[ ]',
      '[x]',
    ]);
    expect(text.substring(marks[1] + 2), startsWith(' quoted'));
    expect(taskMarks('1. [ ] one\n2. [x] two'), hasLength(2));
  });

  testWidgets('tap in preview edits at the tapped line', (tester) async {
    await _openPreview(tester);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    await tester.tap(find.textContaining('first line', findRichText: true));
    await _settle(tester);
    final field = tester.widget<TextField>(_sourceField);
    expect(field.controller!.selection.baseOffset, inInclusiveRange(9, 19));
    expect(field.focusNode!.hasFocus, isTrue);
    expect(find.byTooltip('Preview'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('edit button opens the source and the checkbox keeps preview', (
    tester,
  ) async {
    await _openPreview(tester);
    await tester.tap(find.byType(Checkbox));
    await _settle(tester);
    expect(find.byType(Checkbox), findsOneWidget);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
    await tester.tap(find.byType(FloatingActionButton));
    await _settle(tester);
    expect(_sourceField, findsOneWidget);
    expect(
      tester.widget<TextField>(_sourceField).controller!.text,
      contains('- [x] task'),
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('a pull overlapping unsaved typing becomes a decision', (
    tester,
  ) async {
    final runtime = await _openEditor(tester);
    await tester.enterText(_sourceField, '# Title\n\nmine');
    await tester.runAsync(() async {
      final db = runtime.database;
      final row = await currentRow(runtime);
      await (db.update(db.localNotes)..where((n) => n.id.equals(row.id))).write(
        LocalNotesCompanion(
          content: const Value('# Title\n\ntheirs'),
          baseContent: const Value('# Title\n\ntheirs'),
          revision: Value(row.revision + 1),
        ),
      );
    });
    await _settle(tester);
    await _settle(tester);
    expect(
      tester.widget<TextField>(_sourceField).controller!.text,
      '# Title\n\nmine',
    );
    final row = (await tester.runAsync(() => currentRow(runtime)))!;
    expect(row.syncState, 'needsDecision');
    expect(row.content, '# Title\n\nmine');
    expect(find.text('Resolve synchronization'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('a permission change reaches the open editor', (tester) async {
    final runtime = await _openEditor(tester);
    expect(tester.widget<TextField>(_sourceField).readOnly, isFalse);
    await tester.runAsync(() async {
      final db = runtime.database;
      await db
          .update(db.localNotes)
          .write(const LocalNotesCompanion(readonly: Value(true)));
    });
    await _settle(tester);
    expect(tester.widget<TextField>(_sourceField).readOnly, isTrue);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('read-only note stays read-only in preview', (tester) async {
    await _openPreview(tester, readonly: true);
    expect(find.byType(FloatingActionButton), findsNothing);
    await tester.tap(find.textContaining('first line', findRichText: true));
    await _settle(tester);
    expect(find.byTooltip('Edit source'), findsOneWidget);
    expect(_sourceField, findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
