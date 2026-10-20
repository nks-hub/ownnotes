import 'package:flutter/material.dart';
import '../../design/design.dart';
import '../../l10n/app_localizations.dart';
import '../note_rows.dart';
import '../search/search_filters.dart';

enum NewKind { note, checklist, template, daily }

enum RowAction { open, favorite, move, export, select, delete }

/// Every row of a menu or sheet has a leading outlined icon, in one column.
class MenuRow extends StatelessWidget {
  const MenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.subtitle,
    super.key,
  });
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon),
    title: Text(label),
    subtitle: subtitle == null ? null : Text(subtitle!),
    trailing: selected ? const Icon(Icons.check) : null,
    selected: selected,
    enabled: onTap != null,
    minVerticalPadding: OwnSpace.s,
    contentPadding: EdgeInsets.zero,
    onTap: onTap,
  );
}

/// Note, Checklist, Template and Daily note (spec 4.2).
Future<NewKind?> showNewNoteMenu(BuildContext context) {
  final l = AppLocalizations.of(context)!;
  return showOwnSheet<NewKind>(
    context: context,
    title: l.newNote,
    builder: (sheet) => Column(
      children: [
        MenuRow(
          icon: Icons.note_add_outlined,
          label: l.createNote,
          onTap: () => Navigator.of(sheet).pop(NewKind.note),
        ),
        MenuRow(
          icon: Icons.checklist,
          label: l.createChecklist,
          onTap: () => Navigator.of(sheet).pop(NewKind.checklist),
        ),
        MenuRow(
          icon: Icons.description_outlined,
          label: l.createTemplate,
          onTap: () => Navigator.of(sheet).pop(NewKind.template),
        ),
        MenuRow(
          icon: Icons.today_outlined,
          label: l.createDaily,
          onTap: () => Navigator.of(sheet).pop(NewKind.daily),
        ),
      ],
    ),
  );
}

/// The row menu: the visible alternative to swipe and long press. Entries
/// the note does not allow stay in place but are disabled. [only] limits the
/// menu, as the leading swipe offers just Move and Delete.
Future<RowAction?> showRowMenu(
  BuildContext context,
  NoteRow row, {
  required bool canMove,
  required bool canDelete,
  required bool canFavorite,
  Set<RowAction>? only,
}) {
  final l = AppLocalizations.of(context)!;
  final title = row.title.isEmpty ? l.untitled : row.title;
  return showOwnSheet<RowAction>(
    context: context,
    title: title,
    builder: (sheet) {
      Widget e(RowAction a, IconData icon, String label, bool enabled) =>
          only != null && !only.contains(a)
          ? const SizedBox.shrink()
          : MenuRow(
              icon: icon,
              label: label,
              onTap: enabled ? () => Navigator.of(sheet).pop(a) : null,
            );
      return Column(
        children: [
          e(RowAction.open, Icons.open_in_new, l.openNote, true),
          e(
            RowAction.favorite,
            row.note.favorite ? Icons.star : Icons.star_outline,
            row.note.favorite ? l.rowFavoriteOff : l.rowFavoriteOn,
            canFavorite,
          ),
          e(
            RowAction.move,
            Icons.drive_file_move_outlined,
            l.moveNote,
            canMove,
          ),
          e(RowAction.export, Icons.ios_share, l.bulkExport, true),
          e(RowAction.select, Icons.checklist_rtl, l.selectNotes, true),
          e(RowAction.delete, Icons.delete_outline, l.delete, canDelete),
        ],
      );
    },
  );
}

/// Category chooser for Move and for a new note in an ambiguous view.
/// Returns the category path, empty for uncategorised, null when dismissed.
Future<String?> showCategoryChooser(
  BuildContext context, {
  required List<CategoryNode> tree,
  required String title,
  String? current,
}) {
  final l = AppLocalizations.of(context)!;
  Iterable<Widget> level(
    BuildContext sheet,
    List<CategoryNode> nodes,
    int d,
  ) sync* {
    for (final n in nodes) {
      yield Padding(
        padding: EdgeInsetsDirectional.only(start: d * 16.0),
        child: MenuRow(
          icon: Icons.folder_outlined,
          label: n.name,
          selected: n.path == current,
          onTap: () => Navigator.of(sheet).pop(n.path),
        ),
      );
      yield* level(sheet, n.children, d + 1);
    }
  }

  return showOwnSheet<String>(
    context: context,
    title: title,
    builder: (sheet) => Column(
      children: [
        MenuRow(
          icon: Icons.folder_off_outlined,
          label: l.uncategorised,
          selected: current == '',
          onTap: () => Navigator.of(sheet).pop(''),
        ),
        ...level(sheet, tree, 0),
        MenuRow(
          icon: Icons.create_new_folder_outlined,
          label: l.moveNewCategory,
          onTap: () async {
            final name = await showNameDialog(
              sheet,
              title: l.moveNewCategory,
              hint: l.moveNewCategoryHint,
            );
            if (name != null && sheet.mounted) {
              final cleaned = name
                  .split('/')
                  .map((s) => s.trim())
                  .where((s) => s.isNotEmpty && s != '.' && s != '..')
                  .join('/');
              if (cleaned.isNotEmpty) Navigator.of(sheet).pop(cleaned);
            }
          },
        ),
      ],
    ),
  );
}

/// One short text field in a dialog; null when cancelled or left empty.
Future<String?> showNameDialog(
  BuildContext context, {
  required String title,
  required String hint,
  String initial = '',
}) => showDialog<String>(
  context: context,
  builder: (dialog) => _NameDialog(title: title, hint: hint, initial: initial),
).then((v) => v == null || v.isEmpty ? null : v);

class _NameDialog extends StatefulWidget {
  const _NameDialog({
    required this.title,
    required this.hint,
    required this.initial,
  });
  final String title;
  final String hint;
  final String initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(labelText: widget.hint),
        textInputAction: TextInputAction.done,
        onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: Text(l.save),
        ),
      ],
    );
  }
}

/// Sort order and the less common filters; the quick ones are chips next to
/// the search field. Changes apply at once through [onChanged].
Future<void> showSortFilterSheet(
  BuildContext context, {
  required SortMode sort,
  required NoteFilters filters,
  required void Function(SortMode sort, NoteFilters filters) onChanged,
  required VoidCallback onSaveView,
}) {
  final l = AppLocalizations.of(context)!;
  return showOwnSheet<void>(
    context: context,
    title: l.sortAndFilter,
    builder: (sheet) => StatefulBuilder(
      builder: (context, setState) {
        void change(SortMode s, NoteFilters f) {
          setState(() {
            sort = s;
            filters = f;
          });
          onChanged(s, f);
        }

        Widget heading(String text) => Padding(
          padding: const EdgeInsets.only(top: OwnSpace.m),
          child: Semantics(
            header: true,
            child: Text(text, style: Theme.of(context).textTheme.titleSmall),
          ),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            heading(l.sortTitle),
            MenuRow(
              icon: Icons.schedule,
              label: l.sortByModified,
              selected: sort == SortMode.modified,
              onTap: () => change(SortMode.modified, filters),
            ),
            MenuRow(
              icon: Icons.sort_by_alpha,
              label: l.sortByTitle,
              selected: sort == SortMode.title,
              onTap: () => change(SortMode.title, filters),
            ),
            MenuRow(
              icon: Icons.star_outline,
              label: l.sortFavoritesFirst,
              selected: sort == SortMode.favoritesFirst,
              onTap: () => change(SortMode.favoritesFirst, filters),
            ),
            heading(l.filterSharing),
            MenuRow(
              icon: Icons.group_outlined,
              label: l.filterShared,
              selected: filters.shared,
              onTap: () =>
                  change(sort, filters.copyWith(shared: !filters.shared)),
            ),
            heading(l.filterSync),
            MenuRow(
              icon: Icons.schedule,
              label: l.filterWaiting,
              selected: filters.sync == SyncFilter.waiting,
              onTap: () => change(
                sort,
                filters.sync == SyncFilter.waiting
                    ? filters.copyWith(clearSync: true)
                    : filters.copyWith(sync: SyncFilter.waiting),
              ),
            ),
            MenuRow(
              icon: Icons.rule,
              label: l.filterDecision,
              selected: filters.sync == SyncFilter.decision,
              onTap: () => change(
                sort,
                filters.sync == SyncFilter.decision
                    ? filters.copyWith(clearSync: true)
                    : filters.copyWith(sync: SyncFilter.decision),
              ),
            ),
            const SizedBox(height: OwnSpace.m),
            OwnButton.secondary(
              label: l.saveView,
              icon: Icons.bookmark_add_outlined,
              fullWidth: true,
              onPressed: () {
                Navigator.of(sheet).pop();
                onSaveView();
              },
            ),
          ],
        );
      },
    ),
  );
}
