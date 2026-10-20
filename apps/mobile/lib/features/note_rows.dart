import 'package:notes_store/notes_store.dart';

enum NoteScope { all, favorites, uncategorised, category }

final _lineMarkers = RegExp(
  r'^\s*(?:#{1,6}\s+|>+\s*|[-*+]\s+(?:\[[ xX]\]\s+)?|\d+[.)]\s+)',
);
final _images = RegExp(r'!\[[^\]]*\]\([^)]*\)');
final _links = RegExp(r'\[([^\]]*)\]\([^)]*\)');
final _emphasis = RegExp(r'\*\*|__|`|~~');
final _space = RegExp(r'\s+');
final _rule = RegExp(r'^[-*_=\s]+$');
final _task = RegExp(r'^\s*[-*+]\s+\[([ xX])\]', multiLine: true);

String _plainLine(String line) => line
    .replaceFirst(_lineMarkers, '')
    .replaceAll(_images, '')
    .replaceAllMapped(_links, (m) => m[1]!)
    .replaceAll(_emphasis, '')
    .replaceAll(_space, ' ')
    .trim();

/// A short plain-text preview of [content] for a list row. The first line is
/// skipped when it only repeats [title]; Markdown markers are removed.
String noteExcerpt(String title, String content, {int maxLength = 160}) {
  final wanted = title.trim().toLowerCase();
  final buffer = StringBuffer();
  var first = true;
  var start = 0;
  while (start < content.length && buffer.length < maxLength) {
    var end = content.indexOf('\n', start);
    if (end < 0) end = content.length;
    // One endless line must not cost more than the preview needs.
    final cut = end - start > maxLength * 4 ? start + maxLength * 4 : end;
    final line = _plainLine(content.substring(start, cut));
    start = end + 1;
    if (line.isEmpty || _rule.hasMatch(line)) continue;
    if (first) {
      first = false;
      if (line.toLowerCase() == wanted) continue;
    }
    if (buffer.isNotEmpty) buffer.write(' ');
    buffer.write(line);
  }
  final text = buffer.toString();
  if (text.length <= maxLength) return text;
  var length = maxLength;
  // Do not split a surrogate pair (emoji).
  if ((text.codeUnitAt(length - 1) & 0xFC00) == 0xD800) length--;
  return text.substring(0, length).trimRight();
}

/// Checked and total Markdown task items (`- [ ]`, `- [x]`) in [content].
({int done, int total}) taskProgress(String content) {
  var done = 0;
  var total = 0;
  for (final m in _task.allMatches(content)) {
    total++;
    if (m[1] != ' ') done++;
  }
  return (done: done, total: total);
}

/// A note with everything the list needs, computed once per note revision
/// instead of on every build or scroll.
class NoteRow {
  NoteRow._(
    this.note,
    this.title,
    this.excerpt,
    this.tasksDone,
    this.tasksTotal,
    this.attachments,
    this.haystack,
  );

  factory NoteRow.of(LocalNote note, [NoteRow? previous]) {
    if (previous != null &&
        previous.note.revision == note.revision &&
        previous.note.updatedAt == note.updatedAt &&
        previous.note.title == note.title &&
        previous.note.category == note.category) {
      return NoteRow._(
        note,
        previous.title,
        previous.excerpt,
        previous.tasksDone,
        previous.tasksTotal,
        previous.attachments,
        previous.haystack,
      );
    }
    final title = note.title.trim().isEmpty
        ? titleFromContent(note.content)
        : note.title;
    final tasks = taskProgress(note.content);
    return NoteRow._(
      note,
      title,
      noteExcerpt(title, note.content),
      tasks.done,
      tasks.total,
      note.content.contains('.attachments.'),
      '${note.title}\n${note.content}\n${note.category}'.toLowerCase(),
    );
  }

  final LocalNote note;

  /// Empty when the note has neither a title nor content.
  final String title;
  final String excerpt;
  final int tasksDone;
  final int tasksTotal;
  final bool attachments;

  /// Lowercased title, content and category for search.
  final String haystack;

  bool inScope(NoteScope scope, String category) => switch (scope) {
    NoteScope.all => true,
    NoteScope.favorites => note.favorite,
    NoteScope.uncategorised => note.category.isEmpty,
    NoteScope.category =>
      note.category == category || note.category.startsWith('$category/'),
  };
}

class CategoryNode {
  CategoryNode(this.name, this.path);
  final String name;
  final String path;

  /// Notes in this category and all categories below it.
  int count = 0;
  final children = <CategoryNode>[];
}

/// Builds the tree of `A/B/C` categories from note counts per category.
/// A parent without notes of its own exists as a virtual node.
List<CategoryNode> buildCategoryTree(Map<String, int> counts) {
  final roots = <CategoryNode>[];
  final byPath = <String, CategoryNode>{};
  for (final entry in counts.entries) {
    var siblings = roots;
    var path = '';
    for (final part in entry.key.split('/').where((s) => s.isNotEmpty)) {
      path = path.isEmpty ? part : '$path/$part';
      var node = byPath[path];
      if (node == null) {
        node = CategoryNode(part, path);
        byPath[path] = node;
        siblings.add(node);
      }
      node.count += entry.value;
      siblings = node.children;
    }
  }
  void sort(List<CategoryNode> nodes) {
    nodes.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    for (final n in nodes) {
      sort(n.children);
    }
  }

  sort(roots);
  return roots;
}
