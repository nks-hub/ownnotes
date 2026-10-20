import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/markdown/markdown_document.dart';
import 'emoji_data.dart';

enum SuggestTrigger { mention, emoji, command }

/// The text between a trigger character and the caret.
final class SuggestQuery {
  const SuggestQuery(this.trigger, this.start, this.end, this.query);
  final SuggestTrigger trigger;

  /// Offset of the trigger character; the replaced range is [start], [end].
  final int start;
  final int end;
  final String query;

  @override
  bool operator ==(Object other) =>
      other is SuggestQuery &&
      other.trigger == trigger &&
      other.start == start &&
      other.end == end &&
      other.query == query;

  @override
  int get hashCode => Object.hash(trigger, start, end, query);
}

final _word = RegExp(r'[\p{L}\p{N}_.+\-]', unicode: true);
final _boundaryBefore = RegExp(r'[\s(\[{"' "'" r'>]');

/// The suggestion trigger the caret is in, or null. A trigger counts only at
/// a word boundary (so `me@host`, `10:30` and `a/b` never do), outside code,
/// and not inside a composition that began with the trigger character.
SuggestQuery? detectSuggestion(
  TextEditingValue v,
  MarkdownDocument doc, {
  int? eagerStart,
}) {
  final sel = v.selection;
  if (!sel.isValid || !sel.isCollapsed) return null;
  final text = v.text;
  final caret = sel.start;
  var at = caret;
  while (at > 0 && caret - at < 40 && _word.hasMatch(text[at - 1])) {
    at--;
  }
  if (at == 0) return null;
  final mark = text[at - 1];
  final trigger = switch (mark) {
    '@' => SuggestTrigger.mention,
    ':' => SuggestTrigger.emoji,
    '/' => SuggestTrigger.command,
    _ => null,
  };
  if (trigger == null) return null;
  final start = at - 1;
  if (start > 0 && !_boundaryBefore.hasMatch(text[start - 1])) return null;
  if (v.composing.isValid && v.composing.start <= start && start < v.composing.end) {
    return null;
  }
  if (doc.isInCode(start)) return null;
  final query = text.substring(at, caret);
  // `:` needs two letters so times and ratios stay text; the Insert menu
  // opens the list at once with [eagerStart].
  if (trigger == SuggestTrigger.emoji &&
      start != eagerStart &&
      (query.length < 2 || RegExp(r'^[\d.+\-]+$').hasMatch(query))) {
    return null;
  }
  return SuggestQuery(trigger, start, caret, query);
}

/// What accepting a command row does besides inserting text.
enum SuggestionAction { none, template, reference }

/// One row of the popup.
final class SuggestionItem {
  const SuggestionItem({
    required this.id,
    required this.title,
    this.subtitle,
    this.glyph,
    this.icon,
    this.insert = '',
    this.action = SuggestionAction.none,
    this.caretBack = 0,
  });
  final String id;
  final String title;
  final String? subtitle;

  /// Emoji or initial shown instead of an icon.
  final String? glyph;
  final IconData? icon;

  /// Replaces the trigger and its query.
  final String insert;
  final SuggestionAction action;

  /// Moves the caret back from the end of [insert] (inside a template).
  final int caretBack;
}

/// Results of one query.
final class SuggestionState {
  const SuggestionState({
    required this.query,
    this.items = const [],
    this.loading = false,
    this.error = false,
  });
  final SuggestQuery query;
  final List<SuggestionItem> items;
  final bool loading;

  /// The server could not be asked; the writing goes on regardless.
  final bool error;
}

const _fold = {
  'á': 'a', 'ä': 'a', 'č': 'c', 'ď': 'd', 'é': 'e', 'ě': 'e', 'ë': 'e',
  'í': 'i', 'ň': 'n', 'ó': 'o', 'ö': 'o', 'ř': 'r', 'š': 's', 'ť': 't',
  'ú': 'u', 'ů': 'u', 'ü': 'u', 'ý': 'y', 'ž': 'z', 'ß': 'ss',
};

/// Lower case without Czech and German diacritics, for matching.
String foldForSearch(String s) {
  final lower = s.toLowerCase();
  final out = StringBuffer();
  for (final r in lower.runes) {
    final c = String.fromCharCode(r);
    out.write(_fold[c] ?? c);
  }
  return out.toString();
}

/// Emoji matching [query] in either language, best matches first. [czech]
/// picks the language of the label.
List<SuggestionItem> searchEmoji(String query, {required bool czech}) {
  final q = foldForSearch(query.replaceAll('_', ' '));
  if (q.isEmpty) {
    return [
      for (final e in emojiEntries.take(12))
        SuggestionItem(
          id: 'emoji:${e.glyph}',
          glyph: e.glyph,
          title: (czech ? e.cs : e.en).first,
          insert: e.glyph,
        ),
    ];
  }
  final scored = <(int, EmojiEntry)>[];
  for (final e in emojiEntries) {
    var best = 0;
    for (final names in [e.en, e.cs]) {
      for (var i = 0; i < names.length; i++) {
        final n = foldForSearch(names[i]);
        final bonus = i == 0 ? 0 : 1;
        if (n == q) {
          best = math.max(best, 40 - bonus);
        } else if (n.startsWith(q)) {
          best = math.max(best, 30 - bonus);
        } else if (n.split(' ').any((w) => w.startsWith(q))) {
          best = math.max(best, 20 - bonus);
        } else if (n.contains(q)) {
          best = math.max(best, 10 - bonus);
        }
      }
    }
    if (best > 0) scored.add((best, e));
  }
  scored.sort((a, b) => b.$1.compareTo(a.$1));
  return [
    for (final (_, e) in scored.take(20))
      SuggestionItem(
        id: 'emoji:${e.glyph}',
        glyph: e.glyph,
        title: (czech ? e.cs : e.en).first,
        subtitle: (czech ? e.cs : e.en).skip(1).take(2).join(', '),
        insert: e.glyph,
      ),
  ];
}

/// Where the popup goes, in the coordinates of the area it floats over.
final class PopupPlacement {
  const PopupPlacement({
    required this.rows,
    required this.compact,
    this.left = 0,
    this.top = 0,
    this.width = 0,
  });

  /// Visible rows.
  final int rows;

  /// Docked above the keyboard instead of next to the caret.
  final bool compact;
  final double left;
  final double top;
  final double width;
}

const suggestionRowHeight = 48.0;
const suggestionMaxRows = 5;

/// Places the popup below or above [caret] without covering it. When fewer
/// than two rows fit on either side it becomes a compact bar at the bottom.
PopupPlacement placeSuggestionPopup({
  required Rect caret,
  required Size area,
  required int items,
}) {
  final wanted = items.clamp(1, suggestionMaxRows);
  final width = math.min(340.0, area.width - 16);
  final left = caret.left.clamp(8.0, math.max(8.0, area.width - width - 8));
  final below = area.height - caret.bottom - 4;
  final above = caret.top - 4;
  int fit(double room) => ((room - 8) / suggestionRowHeight).floor();
  if (fit(below) >= wanted) {
    return PopupPlacement(
      rows: wanted,
      compact: false,
      left: left.toDouble(),
      top: caret.bottom + 4,
      width: width,
    );
  }
  if (fit(above) >= wanted) {
    return PopupPlacement(
      rows: wanted,
      compact: false,
      left: left.toDouble(),
      top: caret.top - 4 - (wanted * suggestionRowHeight + 8),
      width: width,
    );
  }
  final side = fit(below) >= fit(above) ? below : above;
  final rows = math.min(wanted, fit(side));
  if (rows >= 2) {
    final top = side == below
        ? caret.bottom + 4
        : caret.top - 4 - (rows * suggestionRowHeight + 8);
    return PopupPlacement(
      rows: rows,
      compact: false,
      left: left.toDouble(),
      top: top,
      width: width,
    );
  }
  return PopupPlacement(
    rows: math.min(wanted, 2),
    compact: true,
    width: area.width,
  );
}
