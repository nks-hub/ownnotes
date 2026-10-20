import 'package:notes_store/notes_store.dart';
import '../core/markdown/markdown_document.dart';

enum NoteScope { all, favorites, uncategorised, category }

/// A short plain-text preview of [content] for a list row. The first line is
/// skipped when it only repeats [title]; Markdown markers are removed.
String noteExcerpt(String title, String content, {int maxLength = 160}) =>
    markdownExcerpt(content, title, maxLength: maxLength);

/// Checked and total Markdown task items (`- [ ]`, `- [x]`) in [content];
/// items in code are not counted, items in block quotes are.
({int done, int total}) taskProgress(String content) {
  final summary = MarkdownDocument.parse(content).taskSummary;
  return (done: summary.done, total: summary.total);
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
    final doc = MarkdownDocument.parse(note.content);
    final tasks = doc.taskSummary;
    return NoteRow._(
      note,
      title,
      doc.excerpt(title),
      tasks.done,
      tasks.total,
      doc.attachments.isNotEmpty,
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
