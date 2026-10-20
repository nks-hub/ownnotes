import '../../core/markdown/markdown_document.dart';

/// A task item with the lines of its whole block: the item line, its
/// continuation paragraphs and nested items.
final class ChecklistItem {
  const ChecklistItem({
    required this.task,
    required this.firstLine,
    required this.lastLine,
    required this.depth,
    required this.parent,
    required this.indent,
  });
  final TaskItem task;
  final int firstLine;
  final int lastLine;

  /// Number of enclosing task items.
  final int depth;

  /// Index of the enclosing item in [Checklist.items], or -1.
  final int parent;
  final int indent;

  bool get checked => task.checked;
  String get label => task.label;
}

/// Parser-backed view of the tasks of a note. Every edit is computed on the
/// source lines and touches only the task marker, the lines of one block, or
/// the lines added or removed; headings, prose and the rest keep their bytes.
final class Checklist {
  Checklist._(this.text, this.doc, this.items);

  factory Checklist.parse(String text) {
    final doc = MarkdownDocument.parse(text);
    int indentOf(MdLine l) {
      var w = 0;
      for (var i = l.start; i < l.end; i++) {
        final c = text.codeUnitAt(i);
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

    final raw = <(TaskItem, int, int, int)>[];
    for (final t in doc.tasks) {
      if (t.quoted) continue;
      final first = doc.lineAt(t.line.start);
      final indent = indentOf(doc.lines[first]);
      var last = first;
      for (var l = first + 1; l < doc.lines.length; l++) {
        final line = doc.lines[l];
        if (line.blank) continue;
        if (indentOf(line) > indent) {
          last = l;
        } else {
          break;
        }
      }
      raw.add((t, first, last, indent));
    }
    final items = <ChecklistItem>[];
    for (var i = 0; i < raw.length; i++) {
      final (task, first, last, indent) = raw[i];
      var parent = -1;
      for (var j = i - 1; j >= 0; j--) {
        if (raw[j].$2 < first && raw[j].$3 >= first) {
          parent = j;
          break;
        }
      }
      items.add(
        ChecklistItem(
          task: task,
          firstLine: first,
          lastLine: last,
          depth: parent < 0 ? 0 : items[parent].depth + 1,
          parent: parent,
          indent: indent,
        ),
      );
    }
    return Checklist._(text, doc, items);
  }

  final String text;
  final MarkdownDocument doc;
  final List<ChecklistItem> items;

  int get total => items.length;
  int get completed => items.where((i) => i.checked).length;

  /// `text` with the marker of [item] flipped, or null when the source no
  /// longer holds that task there.
  String? toggled(ChecklistItem item) => doc.toggled(text, item.task);

  List<String> get _lines => text.split('\n');

  /// Adds an unchecked item after the last top-level item (or at the end when
  /// there is none), using that item's list marker and indent.
  String? added(String label) {
    final clean = label.replaceAll(RegExp(r'\s*\n\s*'), ' ').trim();
    if (clean.isEmpty) return null;
    final lines = _lines;
    final top = items.where((i) => i.depth == 0).toList();
    if (top.isEmpty) {
      final body = text.trimRight();
      return body.isEmpty ? '- [ ] $clean\n' : '$body\n\n- [ ] $clean\n';
    }
    final anchor = top.last;
    final m = RegExp(
      r'^([ \t]*)(?:([-+*])|(\d{1,9})([.)]))([ \t]+)',
    ).firstMatch(lines[anchor.firstLine])!;
    final marker = m[3] == null ? m[2]! : '${int.parse(m[3]!) + 1}${m[4]}';
    final entry = '${m[1]}$marker${m[5]}[ ] $clean';
    lines.insert(anchor.lastLine + 1, entry);
    return lines.join('\n');
  }

  /// Items that "Clear completed" removes: checked, with no open item below
  /// them. Nested checked items go with their checked parent.
  List<ChecklistItem> get clearable {
    bool hasOpenBelow(int index) {
      final item = items[index];
      for (var j = index + 1; j < items.length; j++) {
        if (items[j].firstLine > item.lastLine) break;
        if (!items[j].checked) return true;
      }
      return false;
    }

    final out = <ChecklistItem>[];
    for (var i = 0; i < items.length; i++) {
      if (items[i].checked && !hasOpenBelow(i)) {
        // Skip items inside a block that is removed anyway.
        if (out.isNotEmpty && items[i].firstLine <= out.last.lastLine) continue;
        out.add(items[i]);
      }
    }
    return out;
  }

  /// Number of checked items "Clear completed" would remove.
  int get clearableCount {
    var n = 0;
    for (final b in clearable) {
      n += items
          .where((i) => i.firstLine >= b.firstLine && i.lastLine <= b.lastLine && i.checked)
          .length;
    }
    return n;
  }

  /// Text without the blocks of [clearable] items.
  String cleared() {
    final lines = _lines;
    for (final b in clearable.reversed) {
      lines.removeRange(b.firstLine, b.lastLine + 1);
    }
    return lines.join('\n');
  }

  bool _gapBlank(int fromLine, int toLine) {
    for (var l = fromLine + 1; l < toLine; l++) {
      if (!doc.lines[l].blank) return false;
    }
    return true;
  }

  /// Index of the sibling directly above [index], or -1.
  int previousSibling(int index) {
    final item = items[index];
    for (var j = index - 1; j >= 0; j--) {
      final o = items[j];
      if (o.parent == item.parent && o.depth == item.depth) {
        return o.lastLine < item.firstLine && _gapBlank(o.lastLine, item.firstLine)
            ? j
            : -1;
      }
    }
    return -1;
  }

  /// Index of the sibling directly below [index], or -1.
  int nextSibling(int index) {
    final item = items[index];
    for (var j = index + 1; j < items.length; j++) {
      final o = items[j];
      if (o.firstLine <= item.lastLine) continue;
      if (o.parent == item.parent && o.depth == item.depth) {
        return _gapBlank(item.lastLine, o.firstLine) ? j : -1;
      }
      if (o.depth < item.depth) return -1;
    }
    return -1;
  }

  /// Text with the block of [index] moved above its previous sibling.
  String? movedUp(int index) {
    final p = previousSibling(index);
    return p < 0 ? null : movedTo(index, p);
  }

  /// Text with the block of [index] moved below its next sibling.
  String? movedDown(int index) {
    final n = nextSibling(index);
    return n < 0 ? null : movedTo(index, n);
  }

  /// Text with the block of [from] moved to the place of [to], or null when
  /// they are not siblings in one run of the same list. Blank lines between
  /// the blocks stay where they were.
  String? movedTo(int from, int to) {
    if (from == to) return null;
    final chain = <int>[from];
    for (var p = previousSibling(from); p >= 0; p = previousSibling(p)) {
      chain.insert(0, p);
    }
    for (var n = nextSibling(from); n >= 0; n = nextSibling(n)) {
      chain.add(n);
    }
    if (!chain.contains(to)) return null;
    final lines = _lines;
    final blocks = [
      for (final i in chain) lines.sublist(items[i].firstLine, items[i].lastLine + 1),
    ];
    final gaps = [
      for (var k = 0; k < chain.length - 1; k++)
        lines.sublist(items[chain[k]].lastLine + 1, items[chain[k + 1]].firstLine),
    ];
    final order = List<int>.generate(chain.length, (k) => k);
    order.removeAt(chain.indexOf(from));
    order.insert(chain.indexOf(to), chain.indexOf(from));
    final out = <String>[];
    for (var k = 0; k < order.length; k++) {
      out.addAll(blocks[order[k]]);
      if (k < gaps.length) out.addAll(gaps[k]);
    }
    lines.replaceRange(items[chain.first].firstLine, items[chain.last].lastLine + 1, out);
    return lines.join('\n');
  }
}
