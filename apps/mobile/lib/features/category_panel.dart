import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'note_rows.dart';

/// Scope list and collapsible category tree, shown in a drawer on phones and
/// as a side panel on wide screens.
class CategoryPanel extends StatelessWidget {
  const CategoryPanel({
    super.key,
    required this.tree,
    required this.total,
    required this.favorites,
    required this.uncategorised,
    required this.scope,
    required this.category,
    required this.expanded,
    required this.onSelect,
    required this.onToggle,
  });

  final List<CategoryNode> tree;
  final int total;
  final int favorites;
  final int uncategorised;
  final NoteScope scope;
  final String category;
  final Set<String> expanded;
  final void Function(NoteScope scope, String category) onSelect;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final entries = <Widget>[
      _entry(
        context,
        Icons.notes,
        l.allNotes,
        total,
        scope == NoteScope.all,
        () => onSelect(NoteScope.all, ''),
      ),
      _entry(
        context,
        Icons.star_outline,
        l.favorites,
        favorites,
        scope == NoteScope.favorites,
        () => onSelect(NoteScope.favorites, ''),
      ),
      if (uncategorised > 0 && tree.isNotEmpty)
        _entry(
          context,
          Icons.folder_off_outlined,
          l.uncategorised,
          uncategorised,
          scope == NoteScope.uncategorised,
          () => onSelect(NoteScope.uncategorised, ''),
        ),
      if (tree.isNotEmpty) ...[
        const Divider(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Text(
            l.categories,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        ..._branch(context, tree, 0),
      ],
    ];
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: entries,
      ),
    );
  }

  Iterable<Widget> _branch(
    BuildContext context,
    List<CategoryNode> nodes,
    int depth,
  ) sync* {
    for (final node in nodes) {
      final open = expanded.contains(node.path);
      yield _entry(
        context,
        null,
        node.name,
        node.count,
        scope == NoteScope.category && category == node.path,
        () => onSelect(NoteScope.category, node.path),
        depth: depth,
        toggle: node.children.isEmpty
            ? null
            : (open: open, onTap: () => onToggle(node.path)),
      );
      if (open) yield* _branch(context, node.children, depth + 1);
    }
  }

  Widget _entry(
    BuildContext context,
    IconData? icon,
    String name,
    int count,
    bool selected,
    VoidCallback onTap, {
    int depth = 0,
    ({bool open, VoidCallback onTap})? toggle,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ListTile(
        dense: true,
        selected: selected,
        selectedTileColor: scheme.secondaryContainer,
        selectedColor: scheme.onSecondaryContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: EdgeInsets.only(left: 4.0 + depth * 16, right: 16),
        leading: icon != null
            ? Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Icon(icon),
              )
            : SizedBox(
                width: 40,
                child: toggle == null
                    ? null
                    : IconButton(
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          toggle.open ? Icons.expand_more : Icons.chevron_right,
                        ),
                        onPressed: toggle.onTap,
                      ),
              ),
        title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Text('$count'),
        onTap: onTap,
      ),
    );
  }
}
