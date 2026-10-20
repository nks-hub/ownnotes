import 'package:flutter/material.dart';
import 'live_styling.dart';
import 'markdown_document.dart';

/// Edit-mode controller that styles the Markdown while it is typed. It never
/// rewrites the value, so selection, undo history and focus are untouched.
class MarkdownTextController extends TextEditingController {
  MarkdownTextController({super.text});

  bool _monospace = false;
  String? _cachedText;
  TextStyle? _cachedStyle;
  Brightness? _cachedBrightness;
  Color? _cachedPrimary;
  bool? _cachedMonospace;
  List<TextSpan>? _cached;
  MarkdownDocument? _document;

  /// Body text is the bundled mono font.
  bool get monospace => _monospace;
  set monospace(bool value) {
    if (value == _monospace) return;
    // No notification: the caller sets it while building the field it feeds.
    _monospace = value;
  }

  /// The current text parsed once; shared by styling and callers.
  MarkdownDocument get document {
    final cached = _document;
    if (cached != null && cached.text == text) return cached;
    return _document = MarkdownDocument.parse(text);
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    // Styling a composing region could split it and confuse the keyboard.
    if (withComposing && value.isComposingRangeValid) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    final scheme = Theme.of(context).colorScheme;
    final base = style ?? DefaultTextStyle.of(context).style;
    if (_cached == null ||
        _cachedText != text ||
        _cachedStyle != base ||
        _cachedBrightness != scheme.brightness ||
        _cachedPrimary != scheme.primary ||
        _cachedMonospace != _monospace) {
      _cachedText = text;
      _cachedStyle = base;
      _cachedBrightness = scheme.brightness;
      _cachedPrimary = scheme.primary;
      _cachedMonospace = _monospace;
      _cached = buildLiveMarkdownSpans(
        text,
        base,
        LiveMarkdownStyle(
          marker: scheme.onSurfaceVariant,
          link: scheme.primary,
          codeBackground: scheme.surfaceContainer,
          monospaceBody: _monospace,
        ),
        document: document,
      );
    }
    return TextSpan(style: style, children: _cached);
  }
}
