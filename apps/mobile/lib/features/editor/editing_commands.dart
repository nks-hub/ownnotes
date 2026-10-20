import 'package:flutter/services.dart';

/// Pure Markdown editing commands of the formatting dock. Each takes the
/// current value and returns the value after one command, so the caller can
/// apply it as a single undo step. Selection and text outside the touched
/// lines are never changed.

final _listPrefix = RegExp(
  r'^([ \t]*)([-+*]|\d{1,9}[.)])([ \t]+)(\[[ xX]\][ \t]+)?',
);
final _headingPrefix = RegExp(r'^ {0,3}(#{1,6})[ \t]+');
final _quotePrefix = RegExp(r'^ {0,3}>[ ]?');
final _bulletMarker = RegExp(r'^[-+*]$');

/// Start of the line holding [offset].
int lineStartOf(String text, int offset) =>
    offset <= 0 ? 0 : text.lastIndexOf('\n', offset - 1) + 1;

/// End (before the line break) of the line holding [offset].
int lineEndOf(String text, int offset) {
  final at = text.indexOf('\n', offset);
  return at < 0 ? text.length : at;
}

TextSelection _valid(TextEditingValue v) => v.selection.isValid
    ? v.selection
    : TextSelection.collapsed(offset: v.text.length);

/// The lines touched by the selection; a selection ending at the very start
/// of a line does not include that line.
({int start, int end}) selectedLines(TextEditingValue v) {
  final sel = _valid(v);
  final a = sel.start, b = sel.end;
  final end = b > a && b > 0 && v.text[b - 1] == '\n' ? b - 1 : b;
  return (start: lineStartOf(v.text, a), end: lineEndOf(v.text, end));
}

/// Rewrites every selected line with [edit] and keeps the selection on the
/// same content. [edit] returns the new line text.
TextEditingValue _mapLines(
  TextEditingValue v,
  String Function(String line, int index) edit,
) {
  final block = selectedLines(v);
  final lines = v.text.substring(block.start, block.end).split('\n');
  final starts = <int>[], deltas = <int>[];
  final out = <String>[];
  var at = block.start;
  for (var i = 0; i < lines.length; i++) {
    final changed = edit(lines[i], i);
    starts.add(at);
    deltas.add(changed.length - lines[i].length);
    out.add(changed);
    at += lines[i].length + 1;
  }
  int shift(int offset) {
    var moved = offset;
    for (var i = 0; i < lines.length; i++) {
      final lineEnd = starts[i] + lines[i].length;
      if (offset > lineEnd) {
        moved += deltas[i];
      } else if (offset >= starts[i]) {
        moved += deltas[i];
        // The caret never lands before the line it was in.
        var newStart = block.start;
        for (var j = 0; j < i; j++) {
          newStart += out[j].length + 1;
        }
        if (moved < newStart) moved = newStart;
        return moved;
      }
    }
    return moved;
  }

  final sel = _valid(v);
  return TextEditingValue(
    text: v.text.replaceRange(block.start, block.end, out.join('\n')),
    selection: TextSelection(
      baseOffset: shift(sel.baseOffset),
      extentOffset: shift(sel.extentOffset),
    ),
  );
}

/// Bold, italic, strike: wraps the selection in [left] and [right], or removes
/// them when they are already there. An empty selection inserts the pair and
/// puts the caret between.
TextEditingValue toggleWrap(TextEditingValue v, String left, String right) {
  final text = v.text;
  final sel = _valid(v);
  final a = sel.start, b = sel.end;
  final inner = text.substring(a, b);
  // A single `*` must not count the halves of `**`.
  bool lone(int markerEnd, int markerStart) =>
      left.length > 1 ||
      !(markerEnd - 2 >= 0 && text.substring(markerEnd - 2, markerEnd) == left + left) &&
          !(markerStart + 2 <= text.length &&
              text.substring(markerStart, markerStart + 2) == right + right);
  if (a >= left.length &&
      b + right.length <= text.length &&
      text.substring(a - left.length, a) == left &&
      text.substring(b, b + right.length) == right &&
      lone(a, b)) {
    return TextEditingValue(
      text: text.replaceRange(a - left.length, b + right.length, inner),
      selection: TextSelection(
        baseOffset: a - left.length,
        extentOffset: b - left.length,
      ),
    );
  }
  if (inner.length >= left.length + right.length &&
      inner.startsWith(left) &&
      inner.endsWith(right)) {
    final stripped = inner.substring(left.length, inner.length - right.length);
    return TextEditingValue(
      text: text.replaceRange(a, b, stripped),
      selection: TextSelection(
        baseOffset: a,
        extentOffset: a + stripped.length,
      ),
    );
  }
  return TextEditingValue(
    text: text.replaceRange(a, b, '$left$inner$right'),
    selection: TextSelection(
      baseOffset: a + left.length,
      extentOffset: b + left.length,
    ),
  );
}

/// Inline code, or a fenced block when the selection spans lines.
TextEditingValue toggleCode(TextEditingValue v) {
  final sel = _valid(v);
  if (!v.text.substring(sel.start, sel.end).contains('\n')) {
    return toggleWrap(v, '`', '`');
  }
  final block = selectedLines(v);
  final body = v.text.substring(block.start, block.end);
  final fenced = '```\n$body\n```';
  return TextEditingValue(
    text: v.text.replaceRange(block.start, block.end, fenced),
    selection: TextSelection(
      baseOffset: block.start + 4,
      extentOffset: block.start + 4 + body.length,
    ),
  );
}

/// Heading of [level] on the caret line; the same level again removes it.
TextEditingValue toggleHeading(TextEditingValue v, int level) {
  final sel = _valid(v);
  final start = lineStartOf(v.text, sel.start);
  final end = lineEndOf(v.text, sel.start);
  final line = v.text.substring(start, end);
  final current = _headingPrefix.firstMatch(line);
  final body = current == null ? line : line.substring(current.end);
  final next = current != null && current[1]!.length == level
      ? body
      : '${'#' * level} $body';
  final delta = next.length - line.length;
  final caret = (sel.baseOffset + delta).clamp(start, start + next.length);
  return TextEditingValue(
    text: v.text.replaceRange(start, end, next),
    selection: TextSelection.collapsed(offset: caret),
  );
}

/// Block quote on all selected lines, or off when all already are quoted.
TextEditingValue toggleQuote(TextEditingValue v) {
  final block = selectedLines(v);
  final lines = v.text.substring(block.start, block.end).split('\n');
  final all = lines.every((l) => _quotePrefix.hasMatch(l));
  return _mapLines(
    v,
    (line, _) => all ? line.replaceFirst(_quotePrefix, '') : '> $line',
  );
}

enum ListKind { bullet, numbered }

/// Bullet or numbered list on the selected non-blank lines; applied again it
/// removes the markers. Task markers are kept as part of the item text.
TextEditingValue toggleList(TextEditingValue v, ListKind kind) {
  final block = selectedLines(v);
  final lines = v.text.substring(block.start, block.end).split('\n');
  bool matches(String l) {
    final m = _listPrefix.firstMatch(l);
    if (m == null) return false;
    return (kind == ListKind.bullet) == _bulletMarker.hasMatch(m[2]!);
  }

  final all = lines.where((l) => l.trim().isNotEmpty).every(matches);
  var number = 0;
  return _mapLines(v, (line, _) {
    if (line.trim().isEmpty) return line;
    final m = _listPrefix.firstMatch(line);
    final indent = m?[1] ?? line.substring(0, line.length - line.trimLeft().length);
    final rest = m == null ? line.trimLeft() : line.substring(m.end - (m[4]?.length ?? 0));
    if (all) return '$indent$rest';
    number++;
    return '$indent${kind == ListKind.bullet ? '-' : '$number.'} $rest';
  });
}

/// Task marker on the selected lines: lines that are not tasks become
/// unchecked tasks; when every line already is one, they are all ticked, or
/// all unticked if they already were ticked.
TextEditingValue toggleTask(TextEditingValue v) {
  final block = selectedLines(v);
  final lines = v.text.substring(block.start, block.end).split('\n');
  bool isTask(String l) => _listPrefix.firstMatch(l)?[4] != null;
  final real = lines.where((l) => l.trim().isNotEmpty).toList();
  final allTasks = real.isNotEmpty && real.every(isTask);
  final anyOpen = real.any(
    (l) => isTask(l) && _listPrefix.firstMatch(l)![4]!.trim() == '[ ]',
  );
  return _mapLines(v, (line, _) {
    if (line.trim().isEmpty) return line;
    final m = _listPrefix.firstMatch(line);
    if (allTasks) {
      final mark = anyOpen ? '[x] ' : '[ ] ';
      return line.replaceRange(m!.end - m[4]!.length, m.end, mark);
    }
    if (m == null) {
      final indent = line.substring(0, line.length - line.trimLeft().length);
      return '$indent- [ ] ${line.trimLeft()}';
    }
    if (m[4] != null) return line;
    return line.replaceRange(m.end, m.end, '[ ] ');
  });
}

String _unit(String line) =>
    RegExp(r'^[ \t]*\d{1,9}[.)]').hasMatch(line) ? '   ' : '  ';

/// Indents the selected lines by one list level.
TextEditingValue indent(TextEditingValue v) =>
    _mapLines(v, (line, _) => line.trim().isEmpty ? line : '${_unit(line)}$line');

/// Removes one list level from the selected lines.
TextEditingValue outdent(TextEditingValue v) => _mapLines(v, (line, _) {
  if (line.startsWith('\t')) return line.substring(1);
  final unit = _unit(line).length;
  var n = 0;
  while (n < unit && n < line.length && line[n] == ' ') {
    n++;
  }
  return line.substring(n);
});

/// `[text](url)` around the selection with the address part selected, or an
/// empty label when the selection already is an address.
TextEditingValue insertLink(TextEditingValue v) {
  final sel = _valid(v);
  final picked = v.text.substring(sel.start, sel.end);
  final isUrl = RegExp(r'^https?://\S+$').hasMatch(picked);
  if (isUrl) {
    return TextEditingValue(
      text: v.text.replaceRange(sel.start, sel.end, '[]($picked)'),
      selection: TextSelection.collapsed(offset: sel.start + 1),
    );
  }
  const placeholder = 'https://';
  final label = '[$picked](';
  return TextEditingValue(
    text: v.text.replaceRange(sel.start, sel.end, '$label$placeholder)'),
    selection: TextSelection(
      baseOffset: sel.start + label.length,
      extentOffset: sel.start + label.length + placeholder.length,
    ),
  );
}

/// Replaces [start]..[end] with [insert] and puts the caret after it.
TextEditingValue replaceRange(
  TextEditingValue v,
  int start,
  int end,
  String insert,
) => TextEditingValue(
  text: v.text.replaceRange(start, end, insert),
  selection: TextSelection.collapsed(offset: start + insert.length),
);

/// Inserts [insert] at the selection, replacing it.
TextEditingValue insertAtSelection(TextEditingValue v, String insert) {
  final sel = _valid(v);
  return replaceRange(v, sel.start, sel.end, insert);
}

/// Inserts a trigger character such as `@` at the caret, with a space before
/// it when the previous character would stop the suggestions from opening.
TextEditingValue insertTrigger(TextEditingValue v, String trigger) {
  final sel = _valid(v);
  final before = sel.start == 0 ? '' : v.text[sel.start - 1];
  final needsSpace = before.isNotEmpty && !RegExp(r'[\s(\[{"' "'" r']').hasMatch(before);
  return replaceRange(v, sel.start, sel.end, '${needsSpace ? ' ' : ''}$trigger');
}

/// Enter in a list: continues it with the next marker, or ends the list when
/// the item is empty. Works on the value a keyboard produced ([next]) against
/// the one before ([previous]); returns null when this was not a plain Enter
/// in a list item.
TextEditingValue? continueList(TextEditingValue previous, TextEditingValue next) {
  final sel = previous.selection;
  if (!sel.isValid ||
      !sel.isCollapsed ||
      next.composing.isValid ||
      next.text.length != previous.text.length + 1) {
    return null;
  }
  final at = sel.start;
  if (next.text[at] != '\n' ||
      next.text.replaceRange(at, at + 1, '') != previous.text ||
      next.selection != TextSelection.collapsed(offset: at + 1)) {
    return null;
  }
  final text = previous.text;
  final start = lineStartOf(text, at);
  final line = text.substring(start, at);
  final m = _listPrefix.firstMatch(line);
  if (m == null) return null;
  final after = text.substring(at, lineEndOf(text, at));
  final content = line.substring(m.end) + after;
  if (content.trim().isEmpty) {
    // An empty item ends the list: its marker goes, the line stays empty.
    return TextEditingValue(
      text: text.replaceRange(start, lineEndOf(text, at), ''),
      selection: TextSelection.collapsed(offset: start),
    );
  }
  if (line.substring(m.end).isEmpty && after.isNotEmpty) {
    // The caret sits before the text of the item: a plain line break.
    return null;
  }
  var marker = m[2]!;
  final numeric = RegExp(r'^(\d{1,9})([.)])$').firstMatch(marker);
  if (numeric != null) {
    marker = '${int.parse(numeric[1]!) + 1}${numeric[2]}';
  }
  final task = m[4] != null ? '[ ] ' : '';
  final insert = '\n${m[1]}$marker${m[3]}$task';
  return TextEditingValue(
    text: text.replaceRange(at, at, insert),
    selection: TextSelection.collapsed(offset: at + insert.length),
  );
}

/// Formatter that applies [continueList] in the same edit the keyboard makes,
/// so a continued list is one undo step.
class ListContinuationFormatter extends TextInputFormatter {
  const ListContinuationFormatter();
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => continueList(oldValue, newValue) ?? newValue;
}
