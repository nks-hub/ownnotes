import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextcloudnotes/features/editor/find_bar.dart';
import 'package:nextcloudnotes/l10n/app_localizations.dart';

const _sourceKey = Key('source');

Future<TextEditingController> _open(
  WidgetTester tester,
  String text, {
  Locale locale = const Locale('en'),
  double textScale = 1,
}) async {
  final source = TextEditingController(text: text);
  final query = TextEditingController();
  final focus = FocusNode();
  final searching = ValueNotifier(true);
  addTearDown(() {
    source.dispose();
    query.dispose();
    focus.dispose();
    searching.dispose();
  });
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: ValueListenableBuilder(
        valueListenable: searching,
        builder: (context, active, _) => Scaffold(
          appBar: active
              ? NoteFindBar(
                  source: source,
                  query: query,
                  sourceFocus: focus,
                  onClose: () => searching.value = false,
                )
              : AppBar(
                  actions: [
                    TextButton(
                      onPressed: () => searching.value = true,
                      child: const Text('Open search'),
                    ),
                  ],
                ),
          body: TextField(
            key: _sourceKey,
            controller: source,
            focusNode: focus,
            maxLines: null,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return source;
}

Future<void> _query(WidgetTester tester, String query) async {
  await tester.enterText(
    find.descendant(
      of: find.byType(NoteFindBar),
      matching: find.byType(TextField),
    ),
    query,
  );
  await tester.pump();
}

Future<void> _tap(WidgetTester tester, String tooltip) async {
  await tester.tap(find.byTooltip(tooltip));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('next and previous wrap without changing note text', (
    tester,
  ) async {
    final source = await _open(tester, 'Cat dog CAT');
    await _query(tester, 'cat');
    expect(find.text('0 of 2'), findsOneWidget);
    await _tap(tester, 'Next match');
    expect(
      source.selection,
      const TextSelection(baseOffset: 0, extentOffset: 3),
    );
    expect(find.text('1 of 2'), findsOneWidget);
    await _tap(tester, 'Previous match');
    expect(
      source.selection,
      const TextSelection(baseOffset: 8, extentOffset: 11),
    );
    expect(find.text('2 of 2'), findsOneWidget);
    await _tap(tester, 'Next match');
    expect(source.selection.start, 0);
    expect(source.text, 'Cat dog CAT');
  });

  testWidgets('reopening retains the query and recomputes matches', (
    tester,
  ) async {
    final source = await _open(tester, 'cat cat');
    await _query(tester, 'cat');
    await _tap(tester, 'Cancel');
    source.text = 'dog cat';
    await tester.tap(find.text('Open search'));
    await tester.pumpAndSettle();
    expect(find.text('0 of 1'), findsOneWidget);
    await _tap(tester, 'Next match');
    expect(
      source.selection,
      const TextSelection(baseOffset: 4, extentOffset: 7),
    );
  });

  testWidgets('typing and incoming replacements invalidate stale ranges', (
    tester,
  ) async {
    final source = await _open(tester, 'long prefix cat cat');
    await _query(tester, 'cat');
    await _tap(tester, 'Next match');
    await tester.enterText(find.byKey(_sourceKey), 'cat');
    await tester.pump();
    expect(find.text('0 of 1'), findsOneWidget);
    await _tap(tester, 'Next match');
    expect(
      source.selection,
      const TextSelection(baseOffset: 0, extentOffset: 3),
    );
    source.text = 'dog';
    await tester.pump();
    expect(find.text('0 of 0'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.arrow_downward),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.arrow_upward),
          )
          .onPressed,
      isNull,
    );
    source.text = 'dog cat';
    await tester.pump();
    await _tap(tester, 'Next match');
    expect(source.selection.start, 4);
  });

  testWidgets('literal punctuation and Unicode retain source offsets', (
    tester,
  ) async {
    final source = await _open(tester, 'İ 😀 [ŽLUŤ] [žluť]');
    await _query(tester, '[žluť]');
    await _tap(tester, 'Next match');
    expect(source.selection.textInside(source.text), '[ŽLUŤ]');
    await _tap(tester, 'Next match');
    expect(source.selection.textInside(source.text), '[žluť]');
    await _query(tester, '.*');
    expect(find.text('0 of 0'), findsOneWidget);
    await _query(tester, '');
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.arrow_downward),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('moving the caret clears the current match count', (
    tester,
  ) async {
    final source = await _open(tester, 'cat dog');
    await _query(tester, 'cat');
    await _tap(tester, 'Next match');
    source.selection = const TextSelection.collapsed(offset: 5);
    await tester.pump();
    expect(find.text('0 of 1'), findsOneWidget);
  });

  testWidgets('German search fits 320 dp with 200 percent text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _open(tester, 'text text', locale: const Locale('de'), textScale: 2);
    await _query(tester, 'text');
    expect(tester.takeException(), isNull);
    for (final icon in [Icons.arrow_upward, Icons.arrow_downward]) {
      final size = tester.getSize(find.widgetWithIcon(IconButton, icon));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    }
  });
}
