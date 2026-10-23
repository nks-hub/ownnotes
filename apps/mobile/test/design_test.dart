import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextcloudnotes/design/design.dart';

double luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

double contrast(Color a, Color b) {
  final la = luminance(a), lb = luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  group('colour roles', () {
    const themes = {'light': OwnColors.light, 'dark': OwnColors.dark};

    test('roles are exactly the specified hex values and opaque', () {
      expect(OwnColors.light.canvas, const Color(0xFFFAF8F3));
      expect(OwnColors.light.accent, const Color(0xFF805400));
      expect(OwnColors.light.infoContainer, const Color(0xFFE4EFF9));
      expect(OwnColors.dark.document, const Color(0xFF20201C));
      expect(OwnColors.dark.selected, const Color(0xFF493715));
      expect(OwnColors.dark.decision, const Color(0xFFFFBE80));
      for (final c in themes.values) {
        for (final color in [
          c.canvas,
          c.document,
          c.raised,
          c.text,
          c.textSecondary,
          c.outline,
          c.accent,
          c.onAccent,
          c.selected,
          c.onSelected,
          c.error,
          c.errorContainer,
          c.success,
          c.successContainer,
          c.decision,
          c.decisionContainer,
          c.info,
          c.infoContainer,
        ]) {
          expect(color.a, 1.0);
        }
      }
    });

    for (final entry in themes.entries) {
      final c = entry.value;
      final name = entry.key;
      test('$name: text pairings reach 4.5:1', () {
        final pairs = <String, (Color, Color)>{
          'text/canvas': (c.text, c.canvas),
          'text/document': (c.text, c.document),
          'text/raised': (c.text, c.raised),
          'secondary/canvas': (c.textSecondary, c.canvas),
          'secondary/document': (c.textSecondary, c.document),
          'secondary/raised': (c.textSecondary, c.raised),
          'accent/canvas': (c.accent, c.canvas),
          'accent/document': (c.accent, c.document),
          'accent/raised': (c.accent, c.raised),
          'onAccent/accent': (c.onAccent, c.accent),
          'onSelected/selected': (c.onSelected, c.selected),
          'text/selected': (c.text, c.selected),
          'error/errorContainer': (c.error, c.errorContainer),
          'text/errorContainer': (c.text, c.errorContainer),
          'error/canvas': (c.error, c.canvas),
          'success/successContainer': (c.success, c.successContainer),
          'text/successContainer': (c.text, c.successContainer),
          'decision/decisionContainer': (c.decision, c.decisionContainer),
          'text/decisionContainer': (c.text, c.decisionContainer),
          'info/infoContainer': (c.info, c.infoContainer),
          'text/infoContainer': (c.text, c.infoContainer),
        };
        final failing = {
          for (final p in pairs.entries)
            if (contrast(p.value.$1, p.value.$2) < 4.5)
              p.key: contrast(p.value.$1, p.value.$2).toStringAsFixed(2),
        };
        expect(failing, isEmpty);
      });

      test('$name: control outline and graphics reach 3:1', () {
        for (final bg in [c.canvas, c.document, c.raised]) {
          expect(contrast(c.outline, bg), greaterThanOrEqualTo(3.0));
          expect(contrast(c.accent, bg), greaterThanOrEqualTo(3.0));
        }
        expect(contrast(c.accent, c.selected), greaterThanOrEqualTo(3.0));
        for (final tone in OwnTone.values.where((t) => t != OwnTone.neutral)) {
          expect(
            contrast(c.foreground(tone), c.container(tone)),
            greaterThanOrEqualTo(3.0),
          );
        }
      });
    }

    test('the mapped Material schemes keep the same pairings', () {
      for (final theme in [OwnTheme.light(), OwnTheme.dark()]) {
        final s = theme.colorScheme;
        expect(contrast(s.onPrimary, s.primary), greaterThanOrEqualTo(4.5));
        expect(contrast(s.onSurface, s.surface), greaterThanOrEqualTo(4.5));
        expect(
          contrast(s.onSurfaceVariant, s.surfaceContainer),
          greaterThanOrEqualTo(4.5),
        );
        expect(contrast(s.onError, s.error), greaterThanOrEqualTo(4.5));
        expect(
          contrast(s.onPrimaryContainer, s.primaryContainer),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrast(s.onInverseSurface, s.inverseSurface),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          theme.scaffoldBackgroundColor,
          theme.extension<OwnColors>()!.canvas,
        );
      }
    });
  });

  group('type and geometry', () {
    test('roles carry the specified size, line height and weight', () {
      expect(OwnType.screenTitle.fontSize, 22);
      expect(
        OwnType.screenTitle.fontSize! * OwnType.screenTitle.height!,
        closeTo(28, 1e-9),
      );
      expect(
        OwnType.documentTitle.fontSize! * OwnType.documentTitle.height!,
        closeTo(34, 1e-9),
      );
      expect(OwnType.body.fontWeight, FontWeight.w400);
      expect(OwnType.button.fontWeight, FontWeight.w600);
      expect(
        OwnType.metadata.fontSize! * OwnType.metadata.height!,
        closeTo(19, 1e-9),
      );
      expect(
        OwnType.sourceBody.fontSize! * OwnType.sourceBody.height!,
        closeTo(27.2, 1e-9),
      );
      expect(OwnType.previewCode.fontFamily, 'NotoSansMono');
    });

    testWidgets('reduced motion removes durations', (tester) async {
      Duration? seen;
      Future<void> pump(bool reduce) => tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(disableAnimations: reduce),
          child: Builder(
            builder: (c) {
              seen = OwnMotion.of(c, OwnMotion.pane);
              return const SizedBox();
            },
          ),
        ),
      );
      await pump(true);
      expect(seen, Duration.zero);
      await pump(false);
      expect(seen, const Duration(milliseconds: 220));
    });
  });

  group('components render without overflow', () {
    const german = [
      'Speichern auf dem Gerät …',
      'Auf dem Gerät speichern',
      'Benötigt deine Entscheidung',
      'Warten auf das Hochladen',
      'Nach Aktualisierungen suchen',
      'Als separate Notiz behalten',
      'Speichern auf diesem Gerät nicht möglich',
      'Von diesem Gerät entfernen',
      'Notizen durch App-Sperre ausgeblendet',
    ];

    Widget gallery() => SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final g in german) ...[
            OwnButton.primary(label: g, onPressed: () {}),
            OwnButton.secondary(label: g, icon: Icons.add, onPressed: () {}),
            OwnButton.destructive(label: g, onPressed: () {}),
            OwnButton.text(label: g, onPressed: null),
          ],
          OwnBanner(
            tone: OwnTone.error,
            title: german[6],
            message: german[2],
            actions: [
              OwnButton.primary(label: german[1], onPressed: () {}),
              OwnButton.secondary(label: german[5], onPressed: () {}),
              OwnButton.text(label: german[7], onPressed: () {}),
            ],
          ),
          for (final kind in SyncKind.values)
            SyncStatusLine(
              SyncPresentation(
                kind: kind,
                text: german[kind.index % german.length],
                actions: [
                  SyncAction(german[1], () {}),
                  SyncAction(german[5], () {}),
                ],
              ),
            ),
          OwnNoteRowFrame(
            title:
                'Besprechungsnotizen mit einem sehr langen Titel, der umbrechen muss und noch weiter geht',
            excerpt:
                'Entscheidungen vom Montag und die nächsten Schritte, ausführlich beschrieben über mehrere Zeilen',
            meta: const ['Arbeit / Planung', 'Gestern'],
            stateLines: [
              NoteStateLine(
                text: german[2],
                icon: Icons.rule,
                tone: OwnTone.decision,
              ),
              NoteStateLine(text: german[3], icon: Icons.schedule),
            ],
            favorite: true,
            decision: true,
            selected: true,
            semanticLabel: 'row',
            onTap: () {},
          ),
          const SizedBox(
            height: 500,
            child: OwnStateView.error(
              title: 'Datenbank kann nicht geöffnet werden',
              message:
                  'Versuche es erneut oder exportiere die Wiederherstellungsdaten.',
              actions: [],
            ),
          ),
        ],
      ),
    );

    for (final dark in [false, true]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('${dark ? 'dark' : 'light'} at ${scale * 100}% text', (
          tester,
        ) async {
          tester.view.physicalSize = const Size(411, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            MaterialApp(
              theme: OwnTheme.light(),
              darkTheme: OwnTheme.dark(),
              themeMode: dark ? ThemeMode.dark : ThemeMode.light,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Scaffold(body: SafeArea(child: gallery())),
            ),
          );
          expect(tester.takeException(), isNull);
          for (final b in tester.widgetList<OwnButton>(
            find.byType(OwnButton),
          )) {
            final size = tester.getSize(find.byWidget(b));
            expect(size.height, greaterThanOrEqualTo(48), reason: b.label);
          }
        });
      }
    }

    testWidgets('actions stack at large text and keep their order', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(411, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      Future<void> pump(double scale) => tester.pumpWidget(
        MaterialApp(
          theme: OwnTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
            body: OwnActionBar(
              actions: [
                OwnButton.primary(label: 'One', onPressed: () {}),
                OwnButton.secondary(label: 'Two', onPressed: () {}),
              ],
            ),
          ),
        ),
      );
      await pump(1);
      expect(
        tester.getTopLeft(find.text('One')).dy,
        tester.getTopLeft(find.text('Two')).dy,
      );
      await pump(2);
      expect(
        tester.getTopLeft(find.text('One')).dy,
        lessThan(tester.getTopLeft(find.text('Two')).dy),
      );
    });
  });

  group('sync status', () {
    test('priority puts decisions before failures before pending', () {
      final urgent = SyncPresentation.mostUrgent(const [
        SyncPresentation(kind: SyncKind.upToDate, text: 'a'),
        SyncPresentation(kind: SyncKind.savedPending, text: 'b'),
        SyncPresentation(kind: SyncKind.localWriteFailure, text: 'c'),
        SyncPresentation(kind: SyncKind.conflict, text: 'd'),
      ]);
      expect(urgent!.text, 'd');
      expect(SyncPresentation.mostUrgent(const []), isNull);
      final order = [...SyncKind.values]
        ..sort((a, b) => a.priority.compareTo(b.priority));
      expect(order.first, SyncKind.conflict);
      expect(order.last, SyncKind.upToDate);
    });

    test('only critical states are persistent banners', () {
      expect(SyncKind.values.where((k) => k.persistent), [
        SyncKind.authFailure,
        SyncKind.conflict,
        SyncKind.localWriteFailure,
      ]);
    });

    testWidgets('a conflict is a banner with its action, a quiet state a row', (
      tester,
    ) async {
      var pressed = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: OwnTheme.light(),
          home: Scaffold(
            body: Column(
              children: [
                SyncStatusLine(
                  SyncPresentation(
                    kind: SyncKind.conflict,
                    text: '2 notes need your decision',
                    actions: [SyncAction('Needs attention', () => pressed++)],
                  ),
                ),
                const SyncStatusLine(
                  SyncPresentation(
                    kind: SyncKind.upToDate,
                    text: 'Up to date · checked 10:42',
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.byType(OwnBanner), findsOneWidget);
      await tester.tap(find.text('Needs attention'));
      expect(pressed, 1);
      expect(find.text('Up to date · checked 10:42'), findsOneWidget);
    });
  });

  group('sheets and snackbar', () {
    Widget host(void Function(BuildContext) onTap, {double scale = 1}) =>
        MaterialApp(
          theme: OwnTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => onTap(context),
                child: const Text('open'),
              ),
            ),
          ),
        );

    testWidgets('sheet content stays above the system navigation bar', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(bottom: 48);
      tester.view.viewPadding = const FakeViewPadding(bottom: 48);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        host(
          (c) => showOwnSheet<void>(
            context: c,
            title: 'Attachments',
            builder: (_) => const Text('The file stays on the server.'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(
        tester.getBottomLeft(find.text('The file stays on the server.')).dy,
        lessThanOrEqualTo(800 - 48),
      );
    });

    testWidgets('a sheet opens as a sheet on a phone', (tester) async {
      tester.view.physicalSize = const Size(411, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        host(
          (c) => showOwnSheet<void>(
            context: c,
            title: 'Accounts',
            builder: (_) => const Text('body'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('body'), findsOneWidget);
      expect(find.byType(BottomSheet), findsOneWidget);
    });

    testWidgets('a short window or huge text becomes a full screen route', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(411, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        host(
          (c) => showOwnSheet<void>(
            context: c,
            title: 'Accounts',
            builder: (_) => const Text('body'),
          ),
          scale: 2.0,
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('body'), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('a snackbar with undo replaces the previous one', (
      tester,
    ) async {
      var undone = false;
      await tester.pumpWidget(
        host((c) {
          showOwnSnackBar(c, 'first');
          showOwnSnackBar(
            c,
            'Note deleted',
            actionLabel: 'Undo',
            onAction: () => undone = true,
          );
        }),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('first'), findsNothing);
      await tester.tap(find.text('Undo'));
      expect(undone, isTrue);
    });
  });

  group('font asset', () {
    test('the mono subset stays inside the 250 KiB budget', () async {
      final data = await rootBundle.load(
        'assets/fonts/NotoSansMono-Subset.ttf',
      );
      expect(data.lengthInBytes, greaterThan(10 * 1024));
      expect(data.lengthInBytes, lessThanOrEqualTo(250 * 1024));
      // TrueType outlines.
      expect(data.getUint32(0), 0x00010000);
    });

    test('the OFL notice is in the licence registry', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      registerFontLicenses();
      registerFontLicenses();
      final entries = await LicenseRegistry.licenses.toList();
      final mono = entries
          .where((e) => e.packages.contains('Noto Sans Mono'))
          .toList();
      expect(mono, hasLength(1));
      expect(
        mono.single.paragraphs.map((p) => p.text).join(' '),
        contains('SIL OPEN FONT LICENSE'),
      );
    });
  });
}
