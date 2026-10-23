import 'package:notes_store/notes_store.dart';
import '../note_rows.dart';

/// Everything derived from one list of notes, kept between builds.
class NoteIndex {
  NoteIndex({
    required this.notes,
    required this.accountId,
    required this.locked,
    required this.language,
    required this.rows,
    required this.tree,
    required this.paths,
    required this.favorites,
    required this.uncategorised,
    required this.shared,
  });
  factory NoteIndex.build({
    required String accountId,
    required List<LocalNote> notes,
    required bool locked,
    required String language,
    NoteIndex? previousIndex,
  }) {
    final previous = previousIndex?.accountId == accountId
        ? {for (final r in previousIndex!.rows) r.note.id: r}
        : const <String, NoteRow>{};
    final counts = countNotes(notes);
    final tree = buildCategoryTree(counts.categories);
    final paths = <String>{};
    void walk(List<CategoryNode> nodes) {
      for (final n in nodes) {
        paths.add(n.path);
        walk(n.children);
      }
    }

    walk(tree);
    return NoteIndex(
      notes: notes,
      accountId: accountId,
      locked: locked,
      language: language,
      rows: [for (final n in notes) NoteRow.of(n, previous[n.id])],
      tree: tree,
      paths: paths,
      favorites: counts.favorites,
      uncategorised: counts.uncategorised,
      shared: counts.shared,
    );
  }

  final List<LocalNote> notes;
  final String accountId;
  final bool locked;
  final String language;
  final List<NoteRow> rows;
  final List<CategoryNode> tree;
  final Set<String> paths;
  final int favorites;
  final int uncategorised;
  final int shared;
}
