import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextcloudnotes/core/markdown/markdown_document.dart';
import 'package:nextcloudnotes/features/checklist/checklist_model.dart';
import 'package:nextcloudnotes/features/editor/edit_history.dart';
import 'package:nextcloudnotes/features/editor/editing_commands.dart';
import 'package:nextcloudnotes/features/editor/preview_segments.dart';
import 'package:nextcloudnotes/features/editor/suggestion_model.dart';

TextEditingValue v(String text, [int? start, int? end]) => TextEditingValue(
  text: text,
  selection: TextSelection(
    baseOffset: start ?? text.length,
    extentOffset: end ?? start ?? text.length,
  ),
);

void main() {
  group('formatting commands', () {
    test('bold wraps the selection and unwraps it again', () {
      final wrapped = toggleWrap(v('a word b', 2, 6), '**', '**');
      expect(wrapped.text, 'a **word** b');
      expect(wrapped.selection, const TextSelection(baseOffset: 4, extentOffset: 8));
      expect(toggleWrap(wrapped, '**', '**').text, 'a word b');
    });

    test('an empty selection inserts the pair around the caret', () {
      final r = toggleWrap(v('ab', 1), '*', '*');
      expect(r.text, 'a**b');
      expect(r.selection, const TextSelection.collapsed(offset: 2));
    });

    test('italic inside bold does not eat the bold markers', () {
      final r = toggleWrap(v('**word**', 2, 6), '*', '*');
      expect(r.text, '***word***');
    });

    test('heading toggles and replaces another level', () {
      expect(toggleHeading(v('title', 2), 1).text, '# title');
      expect(toggleHeading(v('# title', 4), 1).text, 'title');
      expect(toggleHeading(v('# title', 4), 2).text, '## title');
      expect(toggleHeading(v('a\nb', 3), 3).text, 'a\n### b');
    });

    test('lists apply to every selected line and toggle off', () {
      final on = toggleList(v('a\nb\n\nc', 0, 6), ListKind.bullet);
      expect(on.text, '- a\n- b\n\n- c');
      expect(toggleList(on, ListKind.bullet).text, 'a\nb\n\nc');
      final numbered = toggleList(v('a\nb', 0, 3), ListKind.numbered);
      expect(numbered.text, '1. a\n2. b');
      expect(toggleList(numbered, ListKind.bullet).text, '- a\n- b');
    });

    test('quote and task markers', () {
      expect(toggleQuote(v('a\nb', 0, 3)).text, '> a\n> b');
      expect(toggleQuote(v('> a', 3)).text, 'a');
      expect(toggleTask(v('buy milk', 3)).text, '- [ ] buy milk');
      expect(toggleTask(v('- milk', 3)).text, '- [ ] milk');
      expect(toggleTask(v('- [ ] milk', 3)).text, '- [x] milk');
      expect(toggleTask(v('- [x] milk', 3)).text, '- [ ] milk');
    });

    test('indent and outdent keep the caret on its text', () {
      final r = indent(v('- a\n- b', 7));
      expect(r.text, '- a\n  - b');
      expect(r.selection.baseOffset, 9);
      expect(outdent(r).text, '- a\n- b');
      expect(indent(v('1. a', 4)).text, '   1. a');
    });

    test('code: inline for one line, fenced for several', () {
      expect(toggleCode(v('x', 0, 1)).text, '`x`');
      expect(toggleCode(v('a\nb', 0, 3)).text, '```\na\nb\n```');
    });

    test('link selects the address, or the label of an address', () {
      final link = insertLink(v('see here', 4, 8));
      expect(link.text, 'see [here](https://)');
      expect(link.text.substring(link.selection.start, link.selection.end), 'https://');
      final url = insertLink(v('https://x.y', 0, 11));
      expect(url.text, '[](https://x.y)');
      expect(url.selection, const TextSelection.collapsed(offset: 1));
    });

    test('a trigger gets a space before a word', () {
      expect(insertTrigger(v('word'), '@').text, 'word @');
      expect(insertTrigger(v('word '), '@').text, 'word @');
    });
  });

  group('list continuation', () {
    TextEditingValue? enter(String before, int caret) {
      final old = v(before, caret);
      final next = TextEditingValue(
        text: before.replaceRange(caret, caret, '\n'),
        selection: TextSelection.collapsed(offset: caret + 1),
      );
      return continueList(old, next);
    }

    test('Enter continues bullets, numbers and tasks', () {
      expect(enter('- a', 3)!.text, '- a\n- ');
      expect(enter('3. a', 4)!.text, '3. a\n4. ');
      expect(enter('  - [x] a', 9)!.text, '  - [x] a\n  - [ ] ');
    });

    test('Enter on an empty item leaves the list', () {
      final r = enter('- a\n- ', 6)!;
      expect(r.text, '- a\n');
      expect(r.selection, const TextSelection.collapsed(offset: 4));
    });

    test('Enter outside a list or inside item text is left alone', () {
      expect(enter('plain', 5), isNull);
      expect(enter('- ab', 3)!.text, '- a\n- b');
    });

    test('the formatter makes it one edit', () {
      final out = const ListContinuationFormatter().formatEditUpdate(
        v('- a', 3),
        v('- a\n', 4),
      );
      expect(out.text, '- a\n- ');
    });
  });

  group('undo history', () {
    test('typing joins, a command is its own step, undo and redo', () {
      final c = TextEditingController(text: 'x');
      final h = EditHistory(c, typingWindow: const Duration(hours: 1));
      c.value = v('xa');
      c.value = v('xab');
      expect(h.length, 2);
      h.apply(toggleWrap(v('xab', 0, 3), '**', '**'));
      expect(c.text, '**xab**');
      expect(h.length, 3);
      c.value = v('**xab**c');
      expect(h.length, 4);
      h.undo();
      expect(c.text, '**xab**');
      h.undo();
      expect(c.text, 'xab');
      h.undo();
      expect(c.text, 'x');
      expect(h.canUndo, isFalse);
      h.redo();
      h.redo();
      expect(c.text, '**xab**');
      h.dispose();
    });

    test('a new edit after undo drops the redo steps', () {
      final c = TextEditingController(text: '');
      final h = EditHistory(c);
      h.apply(v('a'));
      h.apply(v('ab'));
      h.undo();
      h.apply(v('ac'));
      expect(h.canRedo, isFalse);
      h.undo();
      expect(c.text, 'a');
      h.dispose();
    });

    test('rebase starts a new history', () {
      final c = TextEditingController(text: 'a');
      final h = EditHistory(c);
      h.apply(v('ab'));
      h.rebase(v('remote'));
      expect(c.text, 'remote');
      expect(h.canUndo, isFalse);
      h.dispose();
    });
  });

  group('suggestion triggers', () {
    SuggestQuery? detect(String text, [int? caret, TextRange? composing]) =>
        detectSuggestion(
          TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: caret ?? text.length),
            composing: composing ?? TextRange.empty,
          ),
          MarkdownDocument.parse(text),
        );

    test('each trigger at a word boundary', () {
      expect(detect('hi @ja')!.trigger, SuggestTrigger.mention);
      expect(detect('hi @ja')!.query, 'ja');
      expect(detect('hi :smi')!.trigger, SuggestTrigger.emoji);
      expect(detect('/hea')!.trigger, SuggestTrigger.command);
      expect(detect('- /')!.query, '');
    });

    test('not in emails, times, paths, urls, code or short emoji queries', () {
      expect(detect('me@host'), isNull);
      expect(detect('at 10:30'), isNull);
      expect(detect('and/or'), isNull);
      expect(detect('see https://x.y/a'), isNull);
      expect(detect('use `@ja'), isNull);
      expect(detect('```\n@ja\n```', 7), isNull);
      expect(detect('hi :s'), isNull);
    });

    test('not while the trigger itself is being composed', () {
      expect(detect('hi @ja', 6, const TextRange(start: 3, end: 6)), isNull);
      expect(detect('hi @ja', 6, const TextRange(start: 4, end: 6)), isNotNull);
    });

    test('emoji are found by English and Czech names, diacritics ignored', () {
      expect(searchEmoji('smile', czech: false).first.glyph, isNotNull);
      expect(searchEmoji('usmev', czech: true).map((e) => e.glyph), contains('🙂'));
      expect(searchEmoji('mleko', czech: true).first.glyph, '🥛');
      expect(searchEmoji('milk', czech: false).first.title, 'milk');
      expect(searchEmoji('mléko', czech: true).first.title, 'mléko');
      expect(searchEmoji('zzzzzz', czech: false), isEmpty);
    });

    test('the popup sits below the caret, above it, or becomes a bar', () {
      const area = Size(400, 600);
      final below = placeSuggestionPopup(
        caret: const Rect.fromLTWH(20, 100, 2, 24),
        area: area,
        items: 5,
      );
      expect(below.compact, isFalse);
      expect(below.top, greaterThan(124));
      final above = placeSuggestionPopup(
        caret: const Rect.fromLTWH(20, 520, 2, 24),
        area: area,
        items: 5,
      );
      expect(above.compact, isFalse);
      expect(above.top + above.rows * 48 + 8, lessThanOrEqualTo(520));
      final bar = placeSuggestionPopup(
        caret: const Rect.fromLTWH(20, 70, 2, 24),
        area: const Size(400, 150),
        items: 5,
      );
      expect(bar.compact, isTrue);
    });
  });

  group('preview segments', () {
    test('callout, details, table and plain blocks keep exact ranges', () {
      const text =
          'intro\n\n::: info\nsome *text*\n:::\n\n| a | b |\n| - | - |\n| 1 | 2 |\n\n'
          '<details>\n<summary>More</summary>\n\nhidden\n\n</details>\n\nsame\n\nsame';
      final segments = buildPreviewSegments(text);
      expect(segments.map((s) => s.runtimeType.toString()), [
        'MarkdownSegment',
        'CalloutSegment',
        'TableSegment',
        'DetailsSegment',
        'MarkdownSegment',
        'MarkdownSegment',
      ]);
      expect(segments[0].range.of(text), 'intro');
      final callout = segments[1] as CalloutSegment;
      expect(callout.kind, CalloutKind.info);
      expect(callout.children.single.range.of(text), 'some *text*');
      expect(segments[2].range.of(text), startsWith('| a | b |'));
      final details = segments[3] as DetailsSegment;
      expect(details.summary, 'More');
      expect(details.children.single.range.of(text), 'hidden');
      // The two equal paragraphs map to their own places.
      expect(segments[4].range.start, isNot(segments[5].range.start));
      expect(segments[5].range.end, text.length);
    });

    test('an unclosed callout stays plain text', () {
      final s = buildPreviewSegments('::: warn\nno end');
      expect(s.single, isA<MarkdownSegment>());
    });

    test('fenced code is not scanned for callouts', () {
      const text = '```\n::: info\nx\n:::\n```';
      expect(buildPreviewSegments(text).single, isA<MarkdownSegment>());
    });
  });

  group('checklist model', () {
    const doc =
        '# Shopping\n\nIntro prose\n\n- [ ] milk\n  note under milk\n- [x] bread\n'
        '- [ ] eggs\n  - [ ] free range\n- [ ] milk\n\nClosing words\n';

    test('toggle changes only the marker', () {
      final cl = Checklist.parse(doc);
      final next = cl.toggled(cl.items.first)!;
      expect(next, doc.replaceFirst('- [ ] milk', '- [x] milk'));
    });

    test('equal labels are told apart by position', () {
      final cl = Checklist.parse(doc);
      final last = cl.items.last;
      expect(last.label, 'milk');
      final next = cl.toggled(last)!;
      expect(next.lastIndexOf('[x] milk'), greaterThan(next.indexOf('[x] bread')));
      expect(next.indexOf('- [ ] milk'), doc.indexOf('- [ ] milk'));
    });

    test('quick add goes after the last top-level item', () {
      final next = Checklist.parse(doc).added('  cheese ')!;
      expect(
        next,
        doc.replaceFirst('- [ ] milk\n\nClosing', '- [ ] milk\n- [ ] cheese\n\nClosing'),
      );
      expect(Checklist.parse('prose only').added('a'), 'prose only\n\n- [ ] a\n');
      expect(Checklist.parse('1. [ ] a\n2. [ ] b').added('c'), '1. [ ] a\n2. [ ] b\n3. [ ] c');
      expect(Checklist.parse(doc).added('   '), isNull);
    });

    test('clear completed keeps prose and open work, counts what goes', () {
      final cl = Checklist.parse(doc);
      expect(cl.clearableCount, 1);
      final cleared = cl.cleared();
      expect(cleared, doc.replaceFirst('- [x] bread\n', ''));
      // A checked parent with an open child is kept.
      final nested = Checklist.parse('- [x] a\n  - [ ] b\n- [x] c');
      expect(nested.clearableCount, 1);
      expect(nested.cleared(), '- [x] a\n  - [ ] b');
    });

    test('moving a block takes its continuation and nested items along', () {
      final cl = Checklist.parse(doc);
      final eggs = cl.items.indexWhere((i) => i.label == 'eggs');
      final up = cl.movedUp(eggs)!;
      expect(
        up,
        '# Shopping\n\nIntro prose\n\n- [ ] milk\n  note under milk\n'
        '- [ ] eggs\n  - [ ] free range\n- [x] bread\n- [ ] milk\n\nClosing words\n',
      );
      expect(cl.movedUp(0), isNull);
      final down = cl.movedDown(0)!;
      expect(down.indexOf('- [x] bread'), lessThan(down.indexOf('note under milk')));
      expect(down, contains('- [x] bread\n- [ ] milk\n  note under milk\n- [ ] eggs'));
    });

    test('drag to another sibling position', () {
      final cl = Checklist.parse('- [ ] a\n- [ ] b\n- [ ] c');
      expect(cl.movedTo(0, 2), '- [ ] b\n- [ ] c\n- [ ] a');
      expect(cl.movedTo(2, 0), '- [ ] c\n- [ ] a\n- [ ] b');
      // Different lists are not siblings.
      final split = Checklist.parse('- [ ] a\n\ntext\n\n- [ ] b');
      expect(split.movedTo(0, 1), isNull);
    });

    test('nested items move within their parent only', () {
      final cl = Checklist.parse('- [ ] p\n  - [ ] x\n  - [ ] y\n- [ ] q');
      final y = cl.items.indexWhere((i) => i.label == 'y');
      expect(cl.movedUp(y), '- [ ] p\n  - [ ] y\n  - [ ] x\n- [ ] q');
      expect(cl.movedDown(y), isNull);
    });

    test('quoted and fenced tasks are not part of the checklist', () {
      final cl = Checklist.parse('> - [ ] quoted\n```\n- [ ] code\n```\n- [ ] real');
      expect(cl.items.map((i) => i.label), ['real']);
    });
  });
}
