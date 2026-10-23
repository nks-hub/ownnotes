import 'dart:convert';
import 'package:markdown/markdown.dart' as md;

/// Half-open range of UTF-16 offsets into the note text, the same unit as
/// `TextSelection` and `String.substring`.
final class SourceRange {
  const SourceRange(this.start, this.end);
  final int start;
  final int end;

  int get length => end - start;
  bool contains(int offset) => offset >= start && offset <= end;
  String of(String source) => source.substring(start, end);

  @override
  bool operator ==(Object other) =>
      other is SourceRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'SourceRange($start, $end)';
}

enum MdBlockKind {
  paragraph,
  heading,
  quote,
  list,
  table,
  fencedCode,
  indentedCode,
  rule,
  html,
}

/// A top-level block of the note, in the order the preview shows them.
final class MdBlock {
  const MdBlock(this.kind, this.range, this.firstLine, this.lastLine, [this.level]);
  final MdBlockKind kind;

  /// Source of the whole block without the final line break.
  final SourceRange range;
  final int firstLine;
  final int lastLine;

  /// Heading level (1 to 6) for [MdBlockKind.heading].
  final int? level;

  bool get isCode =>
      kind == MdBlockKind.fencedCode || kind == MdBlockKind.indentedCode;
}

enum MdLineKind { text, fenceOpen, fenceBody, fenceClose, indentedCode }

final class MdLine {
  const MdLine(this.start, this.end, this.kind, this.quoteDepth, this.blank);

  /// Offsets of the line without its line break (`\n` or `\r\n`).
  final int start;
  final int end;
  final MdLineKind kind;
  final int quoteDepth;
  final bool blank;

  bool get isCode => kind != MdLineKind.text;
}

/// A task item (`- [ ] a`, `1. [x] b`) outside code. Items inside block
/// quotes are included.
final class TaskItem {
  const TaskItem({
    required this.index,
    required this.markOffset,
    required this.checked,
    required this.label,
    required this.occurrence,
    required this.line,
    required this.block,
    required this.quoted,
  });

  /// Position among the document's tasks; the n-th preview checkbox.
  final int index;

  /// Offset of the single character between the brackets.
  final int markOffset;
  final bool checked;
  final String label;

  /// How many tasks with the same label come before this one. Two items
  /// reading "milk" are told apart by it, never by their text.
  final int occurrence;

  /// The whole source line, without the line break.
  final SourceRange line;

  /// Index into [MarkdownDocument.blocks], or -1.
  final int block;
  final bool quoted;

  SourceRange get markRange => SourceRange(markOffset, markOffset + 1);
}

/// A link or image whose destination points into a note's
/// `.attachments.<id>/` folder.
final class AttachmentRef {
  const AttachmentRef({
    required this.path,
    required this.isImage,
    required this.alt,
    required this.destination,
    required this.range,
  });

  /// Percent-decoded destination, for example `.attachments.7/photo 1.png`.
  final String path;
  final bool isImage;
  final String alt;

  /// Source range of the raw destination inside the parentheses.
  final SourceRange destination;
  final SourceRange range;
}

final class TaskSummary {
  const TaskSummary(this.done, this.total);
  final int done;
  final int total;
  bool get isEmpty => total == 0;

  @override
  bool operator ==(Object other) =>
      other is TaskSummary && other.done == done && other.total == total;

  @override
  int get hashCode => Object.hash(done, total);

  @override
  String toString() => 'TaskSummary($done of $total)';
}

/// Normalised task label: letters and digits only, lower case. The preview
/// and the source are compared in this form.
String alnum(String text) =>
    text.toLowerCase().replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '');

final _quoteMark = RegExp(r'^ {0,3}>[ ]?');
final _fenceMark = RegExp(r'^(`{3,}|~{3,})(.*)$');
final _taskLine = RegExp(r'^\s*(?:[-+*]|\d+[.)])\s+\[([ xX])\](?:\s+(.*))?$');
final _listMarker = RegExp(r'^( {0,3})([-+*]|\d{1,9}[.)])(?:[ \t]+(.*)|$)');
final _atx = RegExp(r'^ {0,3}(#{1,6})(?:[ \t]|$)');
final _rule = RegExp(r'^ {0,3}([-*_])(?:[ \t]*\1){2,}[ \t]*$');
final _setext = RegExp(r'^ {0,3}(=+|-+)[ \t]*$');
final _htmlStart = RegExp(r'^ {0,3}<(?:[A-Za-z][A-Za-z0-9-]*[\s/>]|/|!--|\?|![A-Z])');
final _refDefinition = RegExp(r'^ {0,3}\[[^\]]+\]:\s*\S');
final _tableDelim = RegExp(r'^\s*\|?\s*:?-+:?\s*(?:\|\s*:?-+:?\s*)*\|?\s*$');
final _attachmentLink = RegExp(
  r'(!?)\[([^\]]*)\]\(\s*<?([^)\s>]*\.attachments\.[^)\s>]*)>?(?:\s+"[^"]*")?\s*\)',
);
final _inlineCode = RegExp(r'(`+)(?:(?!\1).|\n)+?\1');

/// One parse of a note's Markdown with source ranges for blocks and tasks.
///
/// Built from a line scan that understands fenced and indented code, block
/// quotes and lists. The ranges are exact offsets into the parsed text, so a
/// repeated line or a repeated task label never points at another occurrence.
/// [renderedTasks] and [previewBlocks] confirm the scan against the parser
/// that feeds the preview.
final class MarkdownDocument {
  MarkdownDocument._(
    this.text,
    this.lines,
    this.blocks,
    this.tasks,
  );

  factory MarkdownDocument.parse(String text) => _scan(text);

  final String text;
  final List<MdLine> lines;
  final List<MdBlock> blocks;
  final List<TaskItem> tasks;

  TaskSummary get taskSummary =>
      TaskSummary(tasks.where((t) => t.checked).length, tasks.length);

  /// Index of the line holding [offset].
  int lineAt(int offset) {
    var lo = 0, hi = lines.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (lines[mid].start <= offset) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo;
  }

  /// The block containing [offset], or null between blocks.
  MdBlock? blockAt(int offset) {
    for (final b in blocks) {
      if (b.range.contains(offset)) return b;
    }
    return null;
  }

  bool isInCode(int offset) {
    final line = lines[lineAt(offset)];
    if (line.isCode) return true;
    for (final m in _inlineCode.allMatches(text, line.start)) {
      if (m.start >= line.end) break;
      if (offset > m.start && offset < m.end) return true;
    }
    return false;
  }

  /// Links and images that point into `.attachments.<id>/`, outside code.
  List<AttachmentRef> get attachments {
    final refs = <AttachmentRef>[];
    for (final line in lines) {
      if (line.isCode || line.blank) continue;
      final raw = text.substring(line.start, line.end);
      if (!raw.contains('.attachments.')) continue;
      final skip = [
        for (final m in _inlineCode.allMatches(raw)) SourceRange(m.start, m.end),
      ];
      for (final m in _attachmentLink.allMatches(raw)) {
        if (skip.any((r) => m.start >= r.start && m.start < r.end)) continue;
        final dest = m[3]!;
        final at = line.start + m.start + m[0]!.indexOf(dest);
        var path = dest;
        try {
          path = Uri.decodeFull(dest);
        } on FormatException {
          // Invalid UTF-8 keeps the raw destination.
        } on ArgumentError {
          // A stray % keeps the raw destination.
        }
        refs.add(
          AttachmentRef(
            path: path,
            isImage: m[1] == '!',
            alt: m[2]!,
            destination: SourceRange(at, at + dest.length),
            range: SourceRange(line.start + m.start, line.start + m.end),
          ),
        );
      }
    }
    return refs;
  }

  /// First plain-text line, for list rows: see [markdownExcerpt].
  String excerpt(String title, {int maxLength = 160}) =>
      markdownExcerpt(text, title, maxLength: maxLength);

  /// Tasks the preview renders as checkboxes, in the preview's order. The
  /// preview parser decides which items are tasks; the scan only supplies
  /// where each sits. Empty when the two disagree, so nothing is ticked.
  List<TaskItem> renderedTasks() {
    final expected = <String>[];
    void walk(List<md.Node> nodes) {
      for (var i = 0; i < nodes.length; i++) {
        final node = nodes[i];
        if (node is! md.Element) continue;
        if (node.tag == 'input' && node.attributes['type'] == 'checkbox') {
          final label = StringBuffer();
          for (final next in nodes.skip(i + 1)) {
            if (next is md.Element && (next.tag == 'ul' || next.tag == 'ol')) {
              break;
            }
            label.write(next.textContent);
          }
          expected.add(alnum(label.toString()));
        } else {
          walk(node.children ?? const []);
        }
      }
    }

    walk(_previewNodes(text));
    if (expected.isEmpty) return const [];
    final out = <TaskItem>[];
    var at = 0;
    for (final label in expected) {
      while (at < tasks.length && alnum(tasks[at].label) != label) {
        at++;
      }
      if (at == tasks.length) return const [];
      out.add(tasks[at++]);
    }
    return out;
  }

  /// Blocks in the preview's order, or null when the preview parser sees a
  /// different number of top-level blocks (callers then fall back to text
  /// matching). Index `i` is the i-th top-level child the preview builds.
  List<MdBlock>? previewBlocks() {
    final nodes = _previewNodes(text);
    final count = nodes.where((n) => n is md.Element || _hasText(n)).length;
    return count == blocks.length ? blocks : null;
  }

  /// Source range of the [index]-th preview block, or null when unmapped.
  SourceRange? sourceOfPreviewBlock(int index) {
    final list = previewBlocks();
    if (list == null || index < 0 || index >= list.length) return null;
    return list[index].range;
  }

  /// Offset of the text a preview tap landed on: [word] is the tapped word
  /// and [around] the plain text following it. Matching ignores Markdown
  /// markers. [occurrence] counts equal preview texts before the tapped one,
  /// so a repeated line lands on its own source line; past the last match the
  /// last one is used. The text length when nothing matches.
  int offsetOfText(String word, String around, {int occurrence = 0}) {
    String head(String t) => t.length <= 14 ? t : t.substring(0, 14);
    for (final needle in {head(alnum(around)), alnum(word)}) {
      if (needle.isEmpty) continue;
      var seen = 0;
      int? last;
      for (final line in lines) {
        final raw = text.substring(line.start, line.end);
        if (!alnum(raw).contains(needle)) continue;
        final at = raw.toLowerCase().indexOf(word.toLowerCase());
        last = line.start + (at < 0 ? 0 : at);
        if (seen++ == occurrence) return last;
      }
      if (last != null) return last;
    }
    return text.length;
  }

  /// Replacement text that flips [task], or null when the source no longer
  /// holds that task at that place (the text changed after [tasks] was read).
  String? toggled(String current, TaskItem task) {
    final at = task.markOffset;
    if (at < 1 || at + 1 >= current.length) return null;
    final mark = current[at];
    if ((mark != ' ' && mark != 'x' && mark != 'X') ||
        current[at - 1] != '[' ||
        current[at + 1] != ']' ||
        (mark != ' ') != task.checked) {
      return null;
    }
    final lineEnd = current.indexOf('\n', at);
    final label = current
        .substring(at + 2, lineEnd < 0 ? current.length : lineEnd)
        .trim();
    if (alnum(label) != alnum(task.label)) return null;
    return current.replaceRange(at, at + 1, mark == ' ' ? 'x' : ' ');
  }
}

bool _hasText(md.Node n) => n is md.Text && n.text.trim().isNotEmpty;

List<md.Node> _previewNodes(String text) => md.Document(
  extensionSet: md.ExtensionSet.gitHubFlavored,
  encodeHtml: false,
).parseLines(const LineSplitter().convert(text));

int _indentWidth(String s) {
  var w = 0;
  for (var i = 0; i < s.length; i++) {
    final c = s.codeUnitAt(i);
    if (c == 0x20) {
      w++;
    } else if (c == 0x09) {
      w += 4 - w % 4;
    } else {
      break;
    }
  }
  return w;
}

MarkdownDocument _scan(String text) {
  final lines = <MdLine>[];
  final indents = <int>[];
  final tasks = <TaskItem>[];
  // Per-line facts the block pass needs.
  final stripped = <String>[];
  final taskLineOf = <int>[]; // task index per line or -1

  final counts = <String, int>{};
  var listOpen = false, previousBlank = true;
  String? fence;
  var start = 0;
  while (start <= text.length) {
    var end = text.indexOf('\n', start);
    final hasBreak = end >= 0;
    if (!hasBreak) end = text.length;
    var contentEnd = end;
    if (hasBreak && contentEnd > start && text.codeUnitAt(contentEnd - 1) == 0x0D) {
      contentEnd--;
    }
    final raw = text.substring(start, contentEnd);
    var line = raw;
    var shift = 0, depth = 0;
    for (var q = _quoteMark.firstMatch(line); q != null;) {
      shift += q.end;
      depth++;
      line = line.substring(q.end);
      q = _quoteMark.firstMatch(line);
    }
    final trimmed = line.trimLeft();
    final indent = _indentWidth(line);
    final blank = trimmed.isEmpty;
    var kind = MdLineKind.text;
    var taskAt = -1;

    final marks = _fenceMark.firstMatch(trimmed);
    // A backtick fence cannot carry a backtick in its info string.
    final opens =
        marks != null && !(marks[1]![0] == '`' && marks[2]!.contains('`'));
    if (fence != null) {
      if (marks != null &&
          marks[1]![0] == fence[0] &&
          marks[1]!.length >= fence.length &&
          marks[2]!.trim().isEmpty) {
        kind = MdLineKind.fenceClose;
        fence = null;
      } else {
        kind = MdLineKind.fenceBody;
      }
    } else if (indent >= 4 && previousBlank && !listOpen && !blank) {
      kind = MdLineKind.indentedCode;
    } else if (opens) {
      kind = MdLineKind.fenceOpen;
      fence = marks[1];
    } else {
      final item = _taskLine.firstMatch(line);
      if (item != null) {
        final label = (item[2] ?? '').trim();
        final key = alnum(label);
        final occurrence = counts[key] ?? 0;
        counts[key] = occurrence + 1;
        taskAt = tasks.length;
        tasks.add(
          TaskItem(
            index: tasks.length,
            markOffset: start + shift + line.indexOf('[') + 1,
            checked: item[1] != ' ',
            label: label,
            occurrence: occurrence,
            line: SourceRange(start, contentEnd),
            block: -1,
            quoted: depth > 0,
          ),
        );
      }
      if (_listMarker.hasMatch(line)) {
        listOpen = true;
      } else if (!blank && indent == 0) {
        listOpen = false;
      }
    }
    lines.add(MdLine(start, contentEnd, kind, depth, blank));
    indents.add(indent);
    stripped.add(line);
    taskLineOf.add(taskAt);
    previousBlank = blank;
    if (!hasBreak) break;
    start = end + 1;
  }
  // A trailing line break does not open another (empty) line.
  if (lines.length > 1 && lines.last.start == text.length && text.endsWith('\n')) {
    lines.removeLast();
    indents.removeLast();
    stripped.removeLast();
    taskLineOf.removeLast();
  }

  final blocks = _blocks(text, lines, indents, stripped);
  final owner = List<int>.filled(lines.length, -1);
  for (var b = 0; b < blocks.length; b++) {
    for (var l = blocks[b].firstLine; l <= blocks[b].lastLine; l++) {
      owner[l] = b;
    }
  }
  for (var l = 0; l < taskLineOf.length; l++) {
    final t = taskLineOf[l];
    if (t < 0) continue;
    final old = tasks[t];
    tasks[t] = TaskItem(
      index: old.index,
      markOffset: old.markOffset,
      checked: old.checked,
      label: old.label,
      occurrence: old.occurrence,
      line: old.line,
      block: owner[l],
      quoted: old.quoted,
    );
  }
  return MarkdownDocument._(text, lines, blocks, tasks);
}

List<MdBlock> _blocks(
  String text,
  List<MdLine> lines,
  List<int> indents,
  List<String> stripped,
) {
  final n = lines.length;
  final out = <MdBlock>[];
  bool plain(int i) => lines[i].quoteDepth == 0 && lines[i].kind == MdLineKind.text;
  bool atx(int i) => plain(i) && _atx.hasMatch(stripped[i]);
  bool rule(int i) => plain(i) && _rule.hasMatch(stripped[i]);
  bool listStart(int i) => plain(i) && !rule(i) && _listMarker.hasMatch(stripped[i]);
  bool html(int i) => plain(i) && _htmlStart.hasMatch(stripped[i]);
  bool quote(int i) => lines[i].quoteDepth > 0;
  bool fenceStart(int i) => lines[i].kind == MdLineKind.fenceOpen;
  bool inFence(int i) =>
      lines[i].kind == MdLineKind.fenceBody ||
      lines[i].kind == MdLineKind.fenceClose;
  bool tableStart(int i) =>
      i + 1 < n &&
      plain(i) &&
      plain(i + 1) &&
      stripped[i].contains('|') &&
      stripped[i + 1].contains('|') &&
      _tableDelim.hasMatch(stripped[i + 1]);
  // A non-blank line that cannot be a lazy paragraph continuation.
  bool interrupts(int i) {
    if (atx(i) || rule(i) || quote(i) || fenceStart(i) || html(i) || tableStart(i)) {
      return true;
    }
    if (!listStart(i)) return false;
    final m = _listMarker.firstMatch(stripped[i])!;
    final marker = m[2]!;
    // An ordered item interrupts a paragraph only as number 1, and an empty
    // item never does.
    final ordered = RegExp(r'\d').hasMatch(marker);
    return (m[3] ?? '').isNotEmpty && (!ordered || marker.startsWith('1.') || marker.startsWith('1)'));
  }

  void add(MdBlockKind kind, int first, int last, [int? level]) =>
      out.add(MdBlock(kind, SourceRange(lines[first].start, lines[last].end), first, last, level));

  var i = 0;
  while (i < n) {
    final l = lines[i];
    if (l.blank && l.kind == MdLineKind.text) {
      i++;
      continue;
    }
    if (l.kind == MdLineKind.fenceOpen) {
      var j = i;
      while (j + 1 < n && lines[j].kind != MdLineKind.fenceClose) {
        j++;
      }
      add(MdBlockKind.fencedCode, i, j);
      i = j + 1;
    } else if (l.kind == MdLineKind.indentedCode) {
      var j = i;
      while (true) {
        var m = j + 1;
        while (m < n && lines[m].blank) {
          m++;
        }
        if (m < n && lines[m].kind == MdLineKind.indentedCode) {
          j = m;
        } else {
          break;
        }
      }
      add(MdBlockKind.indentedCode, i, j);
      i = j + 1;
    } else if (quote(i)) {
      var j = i;
      while (j + 1 < n && (quote(j + 1) || !lines[j + 1].blank)) {
        final k = j + 1;
        if (!quote(k) && (atx(k) || rule(k) || fenceStart(k) || listStart(k))) break;
        j = k;
      }
      add(MdBlockKind.quote, i, j);
      i = j + 1;
    } else if (atx(i)) {
      add(MdBlockKind.heading, i, i, _atx.firstMatch(stripped[i])![1]!.length);
      i++;
    } else if (rule(i)) {
      add(MdBlockKind.rule, i, i);
      i++;
    } else if (listStart(i)) {
      var j = i;
      while (j + 1 < n) {
        final k = j + 1;
        if (lines[k].blank) {
          var m = k;
          while (m < n && lines[m].blank) {
            m++;
          }
          if (m >= n) break;
          if (inFence(m) || indents[m] >= 2 || listStart(m)) {
            j = m;
            continue;
          }
          break;
        }
        if (inFence(k)) {
          j = k;
          continue;
        }
        if (atx(k) || rule(k) || (fenceStart(k) && indents[k] < 2) || (quote(k) && indents[k] == 0)) {
          break;
        }
        j = k;
      }
      add(MdBlockKind.list, i, j);
      i = j + 1;
    } else if (html(i)) {
      var j = i;
      while (j + 1 < n && !lines[j + 1].blank) {
        j++;
      }
      add(MdBlockKind.html, i, j);
      i = j + 1;
    } else if (tableStart(i)) {
      var j = i + 1;
      while (j + 1 < n && !lines[j + 1].blank && !interrupts(j + 1)) {
        j++;
      }
      add(MdBlockKind.table, i, j);
      i = j + 1;
    } else if (plain(i) && _refDefinition.hasMatch(stripped[i])) {
      // Link reference definitions render nothing, so they are not blocks.
      i++;
    } else {
      var j = i;
      MdBlockKind kind = MdBlockKind.paragraph;
      int? level;
      while (j + 1 < n) {
        final k = j + 1;
        if (lines[k].blank) break;
        final setext = plain(k) ? _setext.firstMatch(stripped[k]) : null;
        if (setext != null) {
          j = k;
          kind = MdBlockKind.heading;
          level = setext[1]!.startsWith('=') ? 1 : 2;
          break;
        }
        if (interrupts(k)) break;
        j = k;
      }
      add(kind, i, j, level);
      i = j + 1;
    }
  }
  return out;
}

/// A short plain-text preview of [content] for a list row. The first line is
/// skipped when it only repeats [title]; Markdown markers, fence lines and
/// callout fences are removed.
String markdownExcerpt(String content, String title, {int maxLength = 160}) {
  final wanted = title.trim().toLowerCase();
  final buffer = StringBuffer();
  var first = true;
  String? fence;
  var start = 0;
  while (start < content.length && buffer.length < maxLength) {
    var end = content.indexOf('\n', start);
    if (end < 0) end = content.length;
    // One endless line must not cost more than the preview needs.
    final cut = end - start > maxLength * 4 ? start + maxLength * 4 : end;
    final raw = content.substring(start, cut);
    start = end + 1;
    final fenceLine = _fenceMark.firstMatch(raw.trimLeft());
    if (fenceLine != null) {
      final f = fenceLine[1]!;
      if (fence == null) {
        if (!(f[0] == '`' && fenceLine[2]!.contains('`'))) {
          fence = f;
          continue;
        }
      } else if (f[0] == fence[0] && f.length >= fence.length) {
        fence = null;
        continue;
      }
    }
    if (fence == null && raw.trimLeft().startsWith(':::')) continue;
    final line = _plainLine(raw);
    if (line.isEmpty || _plainRule.hasMatch(line)) continue;
    if (first) {
      first = false;
      if (line.toLowerCase() == wanted) continue;
    }
    if (buffer.isNotEmpty) buffer.write(' ');
    buffer.write(line);
  }
  final out = buffer.toString();
  if (out.length <= maxLength) return out;
  var length = maxLength;
  // Do not split a surrogate pair (emoji).
  if ((out.codeUnitAt(length - 1) & 0xFC00) == 0xD800) length--;
  return out.substring(0, length).trimRight();
}

final _lineMarkers = RegExp(
  r'^\s*(?:#{1,6}\s+|>+\s*|[-*+]\s+(?:\[[ xX]\]\s+)?|\d+[.)]\s+)',
);
final _images = RegExp(r'!\[[^\]]*\]\([^)]*\)');
final _links = RegExp(r'\[([^\]]*)\]\([^)]*\)');
final _emphasis = RegExp(r'\*\*|__|`|~~');
final _space = RegExp(r'\s+');
final _plainRule = RegExp(r'^[-*_=\s]+$');

String _plainLine(String line) => line
    .replaceFirst(_lineMarkers, '')
    .replaceAll(_images, '')
    .replaceAllMapped(_links, (m) => m[1]!)
    .replaceAll(_emphasis, '')
    .replaceAll(_space, ' ')
    .trim();
