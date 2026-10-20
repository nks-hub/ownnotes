import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextcloudnotes/core/markdown/live_controller.dart';
import 'package:nextcloudnotes/core/markdown/live_styling.dart';

const _marker = Color(0xFF5C5C52);
const _link = Color(0xFF805400);
const _style = LiveMarkdownStyle(
  marker: _marker,
  link: _link,
  codeBackground: Color(0xFFF0EDE6),
);
const _base = TextStyle(fontSize: 17, height: 1.6);

List<TextSpan> spans(String text, [LiveMarkdownStyle style = _style]) =>
    buildLiveMarkdownSpans(text, _base, style);

TextSpan span(List<TextSpan> all, String text) =>
    all.firstWhere((s) => s.text == text, orElse: () => fail('no span $text'));

void main() {
  test('spans always concatenate to the exact text', () {
    for (final text in [
      '',
      '\n',
      '# H1\n## H2 **b** `c`\n### H3\n#### H4\n##### 5\n###### 6',
      'a\r\n- [ ] one\r\n- [x] two\r\n> quote *it* ~~gone~~\r\n',
      '```dart\nvar a = **x**;\n\n```\nafter\n~~~\nopen fence',
      '😀 # not heading\n# 😀 heading 👨‍👩‍👧 **bold**\n',
      'Žluťoučký kůň `kód` [odkaz](http://x.cz) Größe\n\n  - [X] Prüfung',
      '    indented code\n\ntext\n\n    more code',
      '[a](b)(c) *x* * y * **unclosed',
      '> ```\n> code\n> ```\n1. [ ] x',
    ]) {
      expect(spans(text).map((s) => s.text).join(), text, reason: text);
    }
  });

  group('headings', () {
    test('H1 1.25x and H2 1.15x, H3 to H6 keep the body size, weight 600', () {
      final all = spans('# one\n## two\n### three\n###### six');
      expect(span(all, 'one').style!.fontSize, closeTo(17 * 1.25, 1e-9));
      expect(span(all, 'two').style!.fontSize, closeTo(17 * 1.15, 1e-9));
      expect(span(all, 'three').style!.fontSize, 17);
      expect(span(all, 'six').style!.fontSize, 17);
      for (final t in ['one', 'two', 'three', 'six']) {
        expect(span(all, t).style!.fontWeight, FontWeight.w600);
      }
    });

    test('every heading keeps the body line advance (the 1.6 grid)', () {
      final all = spans('# one\n## two\n### three\nbody');
      for (final t in ['one', 'two', 'three']) {
        final s = span(all, t).style!;
        expect(s.fontSize! * s.height!, closeTo(17 * 1.6, 1e-9), reason: t);
      }
      expect(LiveMarkdownMetrics.onGrid(const TextStyle(fontSize: 17)).height, 1.6);
      expect(LiveMarkdownMetrics.strut(17).height, 1.6);
      expect(LiveMarkdownMetrics.strut(17).forceStrutHeight, isNot(true));
    });

    test('hash signs are markers at the heading size', () {
      final all = spans('## two');
      expect(span(all, '##').style!.color, _marker);
      expect(span(all, '##').style!.fontSize, closeTo(17 * 1.15, 1e-9));
    });
  });

  group('markers and constructs', () {
    test('markers use the secondary colour without opacity', () {
      final all = spans('**b** and `c` [l](u) ~~s~~ *i*\n> q');
      for (final s in all.where((s) => const ['**', '`', '[', '](u)', '~~', '*', '>'].contains(s.text))) {
        expect(s.style!.color, _marker, reason: s.text);
        expect(s.style!.color!.a, 1.0);
      }
    });

    test('bold, italic, strike, link and code', () {
      final all = spans('**b** *i* ~~s~~ [l](u) `c`');
      expect(span(all, 'b').style!.fontWeight, FontWeight.w700);
      expect(span(all, 'i').style!.fontStyle, FontStyle.italic);
      expect(span(all, 's').style!.decoration, TextDecoration.lineThrough);
      expect(span(all, 'l').style!.decoration, TextDecoration.underline);
      expect(span(all, 'l').style!.color, _link);
      expect(span(all, 'c').style!.fontFamily, monoFontFamily);
      expect(span(all, 'c').style!.backgroundColor, const Color(0xFFF0EDE6));
    });

    test('quote text is secondary, tasks keep a visible marker', () {
      final all = spans('> quoted\n- [x] done\n- [ ] open');
      expect(span(all, ' quoted').style!.color, _marker);
      expect(span(all, '[x]').style!.color, _link);
      expect(span(all, 'done').style!.decoration, TextDecoration.lineThrough);
      expect(span(all, 'open').style?.decoration, isNull);
    });

    test('code fences and indented code use upright mono, text inside is not styled', () {
      final all = spans('```dart\n**no**\n```\n\n    # nope');
      expect(span(all, '**no**').style!.fontFamily, monoFontFamily);
      expect(span(all, '```dart').style!.color, _marker);
      expect(span(all, '    # nope').style!.fontFamily, monoFontFamily);
    });

    test('monospace body has no italic and sets the weight axis', () {
      final all = spans(
        '*i* **b**',
        const LiveMarkdownStyle(
          marker: _marker,
          link: _link,
          codeBackground: Colors.grey,
          monospaceBody: true,
        ),
      );
      expect(span(all, 'i').style!.fontStyle, isNull);
      expect(span(all, 'i').style!.fontWeight, FontWeight.w500);
      expect(span(all, 'b').style!.fontVariations, [const FontVariation('wght', 700)]);
    });
  });

  group('controller', () {
    Future<TextSpan> build(
      WidgetTester tester,
      MarkdownTextController controller, {
      required bool composing,
    }) async {
      late TextSpan result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              result = controller.buildTextSpan(
                context: context,
                style: _base,
                withComposing: composing,
              );
              return const SizedBox();
            },
          ),
        ),
      );
      return result;
    }

    testWidgets('styling never touches value, selection or composing range', (tester) async {
      final controller = MarkdownTextController(text: '# head\nbody');
      addTearDown(controller.dispose);
      controller.selection = const TextSelection(baseOffset: 2, extentOffset: 5);
      final before = controller.value;
      final span = await build(tester, controller, composing: false);
      expect(span.toPlainText(), '# head\nbody');
      expect(controller.value, before);
    });

    testWidgets('an active composing range is not restyled', (tester) async {
      final controller = MarkdownTextController();
      addTearDown(controller.dispose);
      controller.value = const TextEditingValue(
        text: '# ahoj',
        selection: TextSelection.collapsed(offset: 6),
        composing: TextRange(start: 2, end: 6),
      );
      final composing = await build(tester, controller, composing: true);
      bool enlarged(InlineSpan s) {
        var found = false;
        s.visitChildren((c) {
          if (c is TextSpan && (c.style?.fontSize ?? 0) > 17) found = true;
          return true;
        });
        return found;
      }

      expect(enlarged(composing), isFalse);
      controller.value = controller.value.copyWith(composing: TextRange.empty);
      final done = await build(tester, controller, composing: true);
      expect(enlarged(done), isTrue);
    });

    testWidgets('the parsed document follows the text', (tester) async {
      final controller = MarkdownTextController(text: '- [ ] a');
      addTearDown(controller.dispose);
      expect(controller.document.tasks, hasLength(1));
      controller.text = '- [ ] a\n- [x] b';
      expect(controller.document.tasks, hasLength(2));
    });
  });
}
