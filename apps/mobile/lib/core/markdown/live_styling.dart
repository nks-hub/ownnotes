import 'package:flutter/material.dart';
import 'markdown_document.dart';

/// Family name of the bundled upright Noto Sans Mono subset (weights 400-700).
const monoFontFamily = 'NotoSansMono';

/// Fallbacks for characters outside the bundled subset.
const monoFontFallback = ['monospace', 'Menlo', 'Courier'];

/// Mono text style; the variable `wght` axis is set explicitly because the
/// asset is one variable file, not one file per weight.
TextStyle monoTextStyle({FontWeight weight = FontWeight.w400}) => TextStyle(
  fontFamily: monoFontFamily,
  fontFamilyFallback: monoFontFallback,
  fontWeight: weight,
  fontVariations: [FontVariation('wght', weight.value.toDouble())],
);

/// Sizes of the live source view (spec section 3.5).
abstract final class LiveMarkdownMetrics {
  /// Line advance of the shared source-line grid, as a multiple of the body
  /// size. Headings fit inside it instead of multiplying it again.
  static const gridMultiplier = 1.6;
  static const h1Scale = 1.25;
  static const h2Scale = 1.15;

  static double headingScale(int level) => switch (level) {
    1 => h1Scale,
    2 => h2Scale,
    _ => 1,
  };

  /// Strut that sets the grid as a minimum line height without forcing it, so
  /// tall glyphs (accents, emoji, fallback scripts) enlarge their line rather
  /// than being clipped.
  static StrutStyle strut(double fontSize, {String? fontFamily}) => StrutStyle(
    fontSize: fontSize,
    fontFamily: fontFamily,
    height: gridMultiplier,
    leading: 0,
  );

  /// [base] with the grid line height applied.
  static TextStyle onGrid(TextStyle base) =>
      base.copyWith(height: gridMultiplier);
}

/// Colours and mode for [buildLiveMarkdownSpans].
final class LiveMarkdownStyle {
  const LiveMarkdownStyle({
    required this.marker,
    required this.link,
    required this.codeBackground,
    this.monospaceBody = false,
  });

  /// Markdown markers and quoted text: the secondary text colour, opaque.
  final Color marker;
  final Color link;
  final Color codeBackground;

  /// The body itself is the mono font. Emphasis then keeps its delimiters and
  /// uses weight, because there is no mono italic.
  final bool monospaceBody;
}

final _inlineMarks = RegExp(
  r'(\*\*|__)(.+?)\1|`([^`]+)`|\[([^\]]*)\]\(([^)]*)\)|~~(.+?)~~|\*(?!\s)(.+?)(?<!\s)\*',
);
final _lineStart = RegExp(
  r'^(\s*)(?:(#{1,6})(\s+)|(>)|([-+*]|\d+[.)])(\s+)(?:(\[[ xX]\])(\s+))?)?',
);

/// Styles raw Markdown for the editor. Every marker stays in the text, so the
/// spans always concatenate to exactly [text]; nothing is rewritten and no
/// offset moves. Headings are larger (H1 1.25x, H2 1.15x, others weight
/// only) but keep the line advance of the body grid.
///
/// [document] may be passed when the caller already parsed [text].
List<TextSpan> buildLiveMarkdownSpans(
  String text,
  TextStyle base,
  LiveMarkdownStyle style, {
  MarkdownDocument? document,
}) {
  final doc = document ?? MarkdownDocument.parse(text);
  final spans = <TextSpan>[];
  void add(String t, [TextStyle? s]) {
    if (t.isNotEmpty) spans.add(TextSpan(text: t, style: s));
  }

  final bodySize = base.fontSize ?? 16;
  final bodyHeight = base.height ?? LiveMarkdownMetrics.gridMultiplier;
  final mono = style.monospaceBody;
  TextStyle weight(FontWeight w) => TextStyle(
    fontWeight: w,
    fontVariations: mono ? [FontVariation('wght', w.value.toDouble())] : null,
  );

  final marker = TextStyle(color: style.marker);
  final code = monoTextStyle().copyWith(backgroundColor: style.codeBackground);

  void inline(String line, [TextStyle? around]) {
    TextStyle merge(TextStyle s) => (around ?? const TextStyle()).merge(s);
    var at = 0;
    for (final m in _inlineMarks.allMatches(line)) {
      add(line.substring(at, m.start), around);
      at = m.end;
      if (m[2] != null) {
        add(m[1]!, marker);
        add(m[2]!, merge(weight(FontWeight.w700)));
        add(m[1]!, marker);
      } else if (m[3] != null) {
        add('`', marker);
        add(m[3]!, merge(code));
        add('`', marker);
      } else if (m[4] != null) {
        add('[', marker);
        add(
          m[4]!,
          merge(
            TextStyle(
              color: style.link,
              decoration: TextDecoration.underline,
              decorationColor: style.link,
            ),
          ),
        );
        add('](${m[5]})', marker);
      } else if (m[6] != null) {
        add('~~', marker);
        add(
          m[6]!,
          merge(const TextStyle(decoration: TextDecoration.lineThrough)),
        );
        add('~~', marker);
      } else {
        add('*', marker);
        add(
          m[7]!,
          merge(
            mono
                ? weight(FontWeight.w500)
                : const TextStyle(fontStyle: FontStyle.italic),
          ),
        );
        add('*', marker);
      }
    }
    add(line.substring(at), around);
  }

  var end = 0;
  for (final line in doc.lines) {
    add(text.substring(end, line.start));
    end = line.end;
    final raw = text.substring(line.start, line.end);
    switch (line.kind) {
      case MdLineKind.fenceOpen || MdLineKind.fenceClose:
        add(raw, marker);
      case MdLineKind.fenceBody || MdLineKind.indentedCode:
        add(raw, code);
      case MdLineKind.text:
        final m = _lineStart.firstMatch(raw)!;
        add(m[1]!);
        final rest = raw.substring(m.end);
        if (m[2] != null) {
          final size =
              bodySize * LiveMarkdownMetrics.headingScale(m[2]!.length);
          final heading = TextStyle(
            fontSize: size,
            // The enlarged run keeps the body's line advance.
            height: bodyHeight * bodySize / size,
          ).merge(weight(FontWeight.w600));
          add(m[2]!, marker.merge(heading));
          add(m[3]!, marker.merge(heading));
          inline(rest, heading);
        } else if (m[4] != null) {
          add('>', marker);
          inline(rest, marker);
        } else {
          if (m[5] != null) {
            add(
              m[5]!,
              TextStyle(color: style.link).merge(weight(FontWeight.w700)),
            );
            add(m[6]!);
          }
          TextStyle? around;
          if (m[7] != null) {
            add(
              m[7]!,
              TextStyle(color: style.link).merge(weight(FontWeight.w700)),
            );
            add(m[8]!);
            if (m[7]!.toLowerCase() == '[x]') {
              around = TextStyle(
                color: style.marker,
                decoration: TextDecoration.lineThrough,
              );
            }
          }
          inline(rest, around);
        }
    }
  }
  add(text.substring(end));
  return spans;
}
