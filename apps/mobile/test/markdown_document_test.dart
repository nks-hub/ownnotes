import 'package:flutter_test/flutter_test.dart';
import 'package:nextcloudnotes/core/markdown/markdown_document.dart';

MarkdownDocument parse(String t) => MarkdownDocument.parse(t);

/// The marks as the characters at each task's offset.
List<String> marks(String text) => [
  for (final t in parse(text).tasks) text[t.markOffset],
];

void main() {
  group('blocks', () {
    test('ranges cover each top-level block and nothing between', () {
      const text =
          '# Title\n\nfirst para\nsecond line\n\n- a\n- b\n\n> quote\n> more\n\n'
          '```dart\ncode\n\nmore\n```\n\n---\n\n| a | b |\n|---|---|\n| 1 | 2 |\n';
      final doc = parse(text);
      expect(
        [for (final b in doc.blocks) b.kind],
        [
          MdBlockKind.heading,
          MdBlockKind.paragraph,
          MdBlockKind.list,
          MdBlockKind.quote,
          MdBlockKind.fencedCode,
          MdBlockKind.rule,
          MdBlockKind.table,
        ],
      );
      expect(doc.blocks[0].range.of(text), '# Title');
      expect(doc.blocks[0].level, 1);
      expect(doc.blocks[1].range.of(text), 'first para\nsecond line');
      expect(doc.blocks[2].range.of(text), '- a\n- b');
      expect(doc.blocks[4].range.of(text), '```dart\ncode\n\nmore\n```');
      expect(doc.blocks[6].range.of(text), '| a | b |\n|---|---|\n| 1 | 2 |');
    });

    test('block count matches the preview parser for common notes', () {
      for (final text in [
        '# A\n\ntext\n\n## B\n\n1. one\n2. two\n\n```\nx\n```\n',
        'Setext\n======\n\npara\n---\n\n- [ ] a\n\n  continued\n- [x] b\n',
        '> q1\n> q2\n\n    indented code\n\n- a\n\n- b\n\n***\n\nend',
        'a\r\n\r\nb\r\n- [ ] c\r\n',
        '| a | b |\n|---|---|\n| 1 | 2 |\n\nafter',
        'x\n| a | b |\n|---|---|\n| 1 | 2 |\ntext after table',
        '<div>\nhtml\n</div>\n\npara',
        '- a\n  - b\n    - c\n\n  para in a\n\n- d\n```\ncode\n```\n',
        '> quote\n>\n> more\n\n> second quote',
        '# H\ntext right after\n- list right after\n> quote\n```\nc\n```\ntext',
        '1. a\n\n   ```\n   code\n\n   more\n   ```\n\n2. b',
        'para\n    still para\n\n    code\n\ntext',
        '[ref]: http://x\n\n[ref]',
        '* * *\n\n- - -\n\n___',
      ]) {
        expect(parse(text).previewBlocks(), isNotNull, reason: text);
      }
    });

    test('a preview block index maps to its own source range', () {
      const text = 'same\n\nsame\n\n# Head\n\nsame';
      final doc = parse(text);
      expect(doc.sourceOfPreviewBlock(0), const SourceRange(0, 4));
      expect(doc.sourceOfPreviewBlock(1), const SourceRange(6, 10));
      expect(doc.sourceOfPreviewBlock(3), const SourceRange(20, 24));
      expect(doc.sourceOfPreviewBlock(9), isNull);
    });

    test('setext headings and lazy continuation stay one block', () {
      const text = 'Title\n=====\n\n> a\nlazy\n\n- item\nlazy item\n';
      final doc = parse(text);
      expect(doc.blocks.map((b) => b.kind), [
        MdBlockKind.heading,
        MdBlockKind.quote,
        MdBlockKind.list,
      ]);
      expect(doc.blocks[0].level, 1);
      expect(doc.blocks[1].range.of(text), '> a\nlazy');
    });

    test('empty and one-line text parse', () {
      expect(parse('').blocks, isEmpty);
      expect(parse('\n').blocks, isEmpty);
      expect(parse('x').blocks.single.range, const SourceRange(0, 1));
    });
  });

  group('tasks', () {
    test('repeated labels map to their own occurrence', () {
      const text = '- [ ] milk\n- [x] eggs\n- [ ] milk\n- [x] milk';
      final doc = parse(text);
      expect(doc.tasks.map((t) => (t.label, t.occurrence)), [
        ('milk', 0),
        ('eggs', 0),
        ('milk', 1),
        ('milk', 2),
      ]);
      expect(doc.tasks[2].markOffset, text.indexOf('milk\n- [x] milk') - 3);
      expect(text[doc.tasks[3].markOffset], 'x');
      expect(doc.taskSummary, const TaskSummary(2, 4));
    });

    test('toggling one duplicate changes only that line', () {
      const text = '- [ ] milk\n- [ ] milk\n';
      final doc = parse(text);
      expect(doc.toggled(text, doc.tasks[1]), '- [ ] milk\n- [x] milk\n');
      expect(doc.toggled(text, doc.tasks[0]), '- [x] milk\n- [ ] milk\n');
    });

    test('fenced, tilde and indented code never hold tasks', () {
      const text =
          'intro\n\n    - [ ] indented code\n\n- [ ] a\n\n'
          '````\n```\n- [ ] fenced\n````\n\n~~~\n- [ ] tilde\n~~~\n- [x] last';
      final doc = parse(text);
      expect(doc.tasks.map((t) => t.label), ['a', 'last']);
      expect(marks(text), [' ', 'x']);
    });

    test('items inside quotes count and are flagged', () {
      const text = '> - [ ] quoted\n> > - [x] deeper\n- [ ] plain';
      final doc = parse(text);
      expect(doc.tasks.map((t) => (t.label, t.quoted)), [
        ('quoted', true),
        ('deeper', true),
        ('plain', false),
      ]);
      expect(text[doc.tasks[1].markOffset], 'x');
      expect(text.substring(doc.tasks[0].markOffset + 2), startsWith(' quoted'));
    });

    test('ordered tasks and nested lists are found, tasks without text too', () {
      final doc = parse('1. [ ] one\n2) [x] two\n   - [ ] nested\n- [ ]\n- [ ]x');
      expect(doc.tasks.map((t) => t.label), ['one', 'two', 'nested', '']);
    });

    test('CRLF offsets are exact', () {
      const text = 'a\r\n- [ ] one\r\n- [x] two\r\n';
      final doc = parse(text);
      expect(doc.tasks.map((t) => text[t.markOffset]), [' ', 'x']);
      expect(doc.tasks[0].line.of(text), '- [ ] one');
      expect(doc.toggled(text, doc.tasks[0]), 'a\r\n- [x] one\r\n- [x] two\r\n');
    });

    test('emoji before a task keep UTF-16 offsets', () {
      const text = '😀 intro 👨‍👩‍👧\n- [ ] 🎉 party\n- [ ] 🎉 party';
      final doc = parse(text);
      expect(text[doc.tasks[0].markOffset], ' ');
      expect(text.substring(doc.tasks[1].markOffset - 3, doc.tasks[1].markOffset + 2), '- [ ]');
      expect(doc.tasks[1].occurrence, 1);
      expect(doc.toggled(text, doc.tasks[1]), contains('- [ ] 🎉 party\n- [x] 🎉 party'));
    });

    test('Czech and German labels compare by letters', () {
      const text = '- [ ] Žluťoučký kůň\n- [x] Größe prüfen\n- [ ] Žluťoučký kůň!';
      final doc = parse(text);
      expect(doc.tasks.map((t) => t.occurrence), [0, 0, 1]);
      expect(doc.taskSummary, const TaskSummary(1, 3));
    });

    test('renderedTasks follow the preview parser, empty on disagreement', () {
      const text = '- [ ] a\n```\n- [ ] code\n```\n1. [x] b';
      expect(parse(text).renderedTasks().map((t) => t.label), ['a', 'b']);
      expect(parse('no tasks here').renderedTasks(), isEmpty);
    });

    test('a stale edit is refused', () {
      const text = '- [ ] a\n- [ ] b';
      final doc = parse(text);
      final task = doc.tasks[1];
      expect(doc.toggled('- [ ] a\n- [x] b', task), isNull);
      expect(doc.toggled('- [ ] a\n- [ ] changed', task), isNull);
      expect(doc.toggled('x', task), isNull);
      expect(doc.toggled(text, task), '- [ ] a\n- [x] b');
    });
  });

  group('attachments and code', () {
    test('references in links and images are found outside code', () {
      const text =
          '![photo](.attachments.7/photo%201.png)\n'
          '[file](.attachments.7/a.pdf "title")\n'
          '`![no](.attachments.7/x.png)`\n'
          '```\n![no](.attachments.7/y.png)\n```\n'
          'plain .attachments. text';
      final refs = parse(text).attachments;
      expect(refs.map((r) => r.path), [
        '.attachments.7/photo 1.png',
        '.attachments.7/a.pdf',
      ]);
      expect(refs.map((r) => r.isImage), [true, false]);
      expect(refs[0].alt, 'photo');
      expect(refs[0].destination.of(text), '.attachments.7/photo%201.png');
    });

    test('isInCode sees fences and inline code', () {
      const text = 'a `b` c\n```\nd\n```\n';
      final doc = parse(text);
      expect(doc.isInCode(text.indexOf('b')), isTrue);
      expect(doc.isInCode(text.indexOf('a')), isFalse);
      expect(doc.isInCode(text.indexOf('d')), isTrue);
    });
  });

  group('excerpt and tap mapping', () {
    test('excerpt drops fence and callout lines, keeps the code text', () {
      const text = '# T\n::: info\nHello **world**\n:::\n```dart\nrun()\n```\n';
      expect(parse(text).excerpt('T'), 'Hello world run()');
    });

    test('repeated text lands on its own occurrence', () {
      const text = 'first\n\nsame line\n\nsame line\n\nsame line';
      final doc = parse(text);
      expect(doc.offsetOfText('same', 'same line'), 7);
      expect(doc.offsetOfText('same', 'same line', occurrence: 1), 18);
      expect(doc.offsetOfText('same', 'same line', occurrence: 2), 29);
      expect(doc.offsetOfText('same', 'same line', occurrence: 9), 29);
      expect(doc.offsetOfText('missing', 'missing'), text.length);
    });
  });
}
