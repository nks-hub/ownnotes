import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextcloudnotes/data/widgets/widget_model.dart';
import 'package:nextcloudnotes/features/widgets/widget_config_screen.dart';
import 'package:nextcloudnotes/l10n/app_localizations.dart';
import 'package:notes_store/notes_store.dart';

LocalNote note(String id, String account, String title, String content) =>
    LocalNote(
      id: id,
      accountId: account,
      title: title,
      content: content,
      category: id == 'n1' ? 'Work' : '',
      favorite: false,
      readonly: false,
      revision: 1,
      syncState: 'clean',
      updatedAt: 1,
      kind: 'note',
    );

Future<void> pump(
  WidgetTester tester, {
  required List<WidgetAccountChoice> accounts,
  required Future<void> Function(WidgetConfig) onSave,
  WidgetConfig? initial,
  Locale locale = const Locale('en'),
  double scale = 1,
}) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final notes = {
    'a': [
      note('n1', 'a', 'Shopping', '- [ ] milk\n'),
      note('n2', 'a', 'Prose only', 'Just words'),
    ],
    'b': [note('n3', 'b', 'Other account', '- [ ] x\n')],
  };
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: WidgetConfigScreen(
        instanceId: '5',
        accounts: accounts,
        notesOf: (id) async => notes[id] ?? const [],
        onSave: onSave,
        onCancel: () {},
        initial: initial,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

const two = [WidgetAccountChoice('a', 'ann'), WidgetAccountChoice('b', 'bob')];

void main() {
  testWidgets('type and account are chosen per instance', (tester) async {
    WidgetConfig? saved;
    await pump(tester, accounts: two, onSave: (c) async => saved = c);
    final add = find.widgetWithText(FilledButton, 'Add widget');
    expect(tester.widget<FilledButton>(add).onPressed, isNull);

    await tester.tap(find.text('bob'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Favorites'));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(add).onPressed, isNotNull);
    await tester.tap(add);
    await tester.pumpAndSettle();

    expect(saved!.instanceId, '5');
    expect(saved!.type, WidgetType.notesList);
    expect(saved!.accountId, 'b');
    expect(saved!.collection!.scope, WidgetScope.favorites);
    expect(saved!.noteId, isNull);
    expect(saved!.isConfigured, isTrue);
  });

  testWidgets('a category is offered from the account notes', (tester) async {
    WidgetConfig? saved;
    await pump(
      tester,
      accounts: const [WidgetAccountChoice('a', 'ann')],
      onSave: (c) async => saved = c,
    );
    await tester.tap(find.text('Work'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add widget'));
    await tester.pumpAndSettle();
    expect(saved!.collection!.scope, WidgetScope.category);
    expect(saved!.collection!.category, 'Work');
  });

  testWidgets('a checklist widget lists only notes with tasks', (tester) async {
    WidgetConfig? saved;
    await pump(
      tester,
      accounts: const [WidgetAccountChoice('a', 'ann')],
      onSave: (c) async => saved = c,
    );
    await tester.tap(find.text('Checklist'));
    await tester.pumpAndSettle();
    expect(find.text('Shopping'), findsOneWidget);
    expect(find.text('Prose only'), findsNothing);
    final add = find.widgetWithText(FilledButton, 'Add widget');
    expect(tester.widget<FilledButton>(add).onPressed, isNull);

    await tester.tap(find.text('Shopping'));
    await tester.pumpAndSettle();
    await tester.tap(add);
    await tester.pumpAndSettle();
    expect(saved!.type, WidgetType.checklist);
    expect(saved!.noteId, 'n1');
    expect(saved!.collection, isNull);
  });

  testWidgets('switching the account drops the note of the old one', (tester) async {
    WidgetConfig? saved;
    await pump(
      tester,
      accounts: two,
      onSave: (c) async => saved = c,
      initial: const WidgetConfig(
        instanceId: '5',
        type: WidgetType.singleNote,
        accountId: 'a',
        noteId: 'n1',
      ),
    );
    final add = find.widgetWithText(FilledButton, 'Add widget');
    expect(tester.widget<FilledButton>(add).onPressed, isNotNull);
    await tester.tap(find.text('bob'));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(add).onPressed, isNull);
    await tester.tap(find.text('Other account'));
    await tester.pumpAndSettle();
    await tester.tap(add);
    await tester.pumpAndSettle();
    expect(saved!.accountId, 'b');
    expect(saved!.noteId, 'n3');
  });

  testWidgets('a failed save stays on the screen with a message', (tester) async {
    await pump(
      tester,
      accounts: const [WidgetAccountChoice('a', 'ann')],
      onSave: (_) async => throw StateError('write'),
    );
    await tester.tap(find.text('All notes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add widget'));
    await tester.pumpAndSettle();
    expect(find.text('The widget could not be configured.'), findsOneWidget);
  });

  testWidgets('no account asks to sign in', (tester) async {
    await pump(tester, accounts: const [], onSave: (_) async {});
    expect(find.text('Sign in to OwnNotes before adding a widget.'), findsOneWidget);
  });

  testWidgets('Czech at 200% text does not overflow', (tester) async {
    await pump(
      tester,
      accounts: two,
      onSave: (_) async {},
      locale: const Locale('cs'),
      scale: 2,
    );
    expect(find.text('Nastavení widgetu'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
