import 'package:flutter/material.dart';
import '../design/design.dart';
import '../l10n/app_localizations.dart';
import 'collection/saved_views.dart';
import 'note_rows.dart';

/// Levels shown inline before a subtree opens on its own (spec 4.2).
const maxInlineLevels = 3;

/// Destinations, saved views and the category tree, in a drawer on phones
/// and as a side panel on wide screens. Selecting a label picks the category
/// with its descendants; a separate 48 px target expands the children.
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
    this.shared = 0,
    this.attention = 0,
    this.savedViews = const [],
    this.activeViewId,
    this.onSelectView,
    this.onDeleteView,
    this.subtree = '',
    this.onSubtree,
    this.onSettings,
  });

  final List<CategoryNode> tree;
  final int total;
  final int favorites;
  final int uncategorised;
  final int shared;
  final int attention;
  final NoteScope scope;
  final String category;
  final Set<String> expanded;
  final void Function(NoteScope scope, String category) onSelect;
  final ValueChanged<String> onToggle;
  final List<SavedView> savedViews;
  final String? activeViewId;
  final ValueChanged<SavedView>? onSelectView;
  final ValueChanged<SavedView>? onDeleteView;

  /// Category whose children are shown on their own; empty for the whole tree.
  final String subtree;
  final ValueChanged<String>? onSubtree;
  final VoidCallback? onSettings;

  static CategoryNode? find(List<CategoryNode> nodes, String path) {
    for (final n in nodes) {
      if (n.path == path) return n;
      if (path.startsWith('${n.path}/')) return find(n.children, path);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final viewActive = activeViewId != null;
    bool on(NoteScope s) => !viewActive && scope == s;
    final root = subtree.isEmpty ? null : find(tree, subtree);
    final nodes = root == null ? tree : root.children;
    final entries = <Widget>[
      _NavRow(
        icon: Icons.notes_outlined,
        label: l.allNotes,
        count: total,
        selected: on(NoteScope.all),
        onTap: () => onSelect(NoteScope.all, ''),
      ),
      _NavRow(
        icon: Icons.star_outline,
        label: l.favorites,
        count: favorites,
        selected: on(NoteScope.favorites),
        onTap: () => onSelect(NoteScope.favorites, ''),
      ),
      _NavRow(
        icon: Icons.folder_off_outlined,
        label: l.uncategorised,
        count: uncategorised,
        selected: on(NoteScope.uncategorised),
        onTap: () => onSelect(NoteScope.uncategorised, ''),
      ),
      _NavRow(
        icon: Icons.group_outlined,
        label: l.sharedWithMe,
        count: shared,
        selected: on(NoteScope.shared),
        onTap: () => onSelect(NoteScope.shared, ''),
      ),
      _NavRow(
        icon: Icons.error_outline,
        label: l.needsAttention,
        count: attention,
        selected: on(NoteScope.attention),
        onTap: () => onSelect(NoteScope.attention, ''),
      ),
      if (savedViews.isNotEmpty) ...[
        const Divider(),
        _Header(l.savedViews, caption: l.onThisDevice),
        for (final v in savedViews)
          _NavRow(
            icon: Icons.bookmark_border,
            label: v.name,
            selected: activeViewId == v.id,
            onTap: () => onSelectView?.call(v),
            trailing: IconButton(
              tooltip: l.deleteView,
              onPressed: () => onDeleteView?.call(v),
              icon: const Icon(Icons.delete_outline),
            ),
          ),
      ],
      if (tree.isNotEmpty) ...[
        const Divider(),
        _Header(l.categories),
        if (root != null) ..._breadcrumb(context, l, root),
        ..._branch(context, l, nodes, 0, viewActive),
      ],
      const Divider(),
      _NavRow(
        icon: Icons.settings_outlined,
        label: l.settings,
        selected: false,
        onTap: onSettings ?? () {},
      ),
    ];
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: OwnSpace.s),
        children: entries,
      ),
    );
  }

  Iterable<Widget> _breadcrumb(
    BuildContext context,
    AppLocalizations l,
    CategoryNode root,
  ) sync* {
    final parts = root.path.split('/');
    yield Padding(
      padding: const EdgeInsets.symmetric(horizontal: OwnSpace.l),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          TextButton(
            onPressed: () => onSubtree?.call(''),
            child: Text(l.allCategoriesUp),
          ),
          for (var i = 0; i < parts.length - 1; i++) ...[
            const Icon(Icons.chevron_right, size: 16),
            TextButton(
              onPressed: () => onSubtree?.call(parts.take(i + 1).join('/')),
              child: Text(parts[i]),
            ),
          ],
        ],
      ),
    );
    yield _NavRow(
      icon: Icons.folder_open_outlined,
      label: root.name,
      count: root.count,
      semanticLabel: l.categoryCount(root.name, root.count),
      selected:
          scope == NoteScope.category &&
          category == root.path &&
          activeViewId == null,
      onTap: () => onSelect(NoteScope.category, root.path),
    );
  }

  Iterable<Widget> _branch(
    BuildContext context,
    AppLocalizations l,
    List<CategoryNode> nodes,
    int depth,
    bool viewActive,
  ) sync* {
    for (final node in nodes) {
      final open = expanded.contains(node.path);
      final deep = depth >= maxInlineLevels - 1;
      Widget? toggle;
      if (node.children.isNotEmpty) {
        toggle = deep
            ? IconButton(
                tooltip: l.openSubtree(node.name),
                onPressed: () => onSubtree?.call(node.path),
                icon: const Icon(Icons.subdirectory_arrow_right),
              )
            : IconButton(
                tooltip: open
                    ? l.collapseCategory(node.name)
                    : l.expandCategory(node.name),
                onPressed: () => onToggle(node.path),
                icon: Icon(open ? Icons.expand_less : Icons.expand_more),
              );
      }
      yield _NavRow(
        icon: open && !deep
            ? Icons.folder_open_outlined
            : Icons.folder_outlined,
        label: node.name,
        count: node.count,
        semanticLabel: l.categoryCount(node.name, node.count),
        depth: depth,
        selected:
            !viewActive && scope == NoteScope.category && category == node.path,
        onTap: () => onSelect(NoteScope.category, node.path),
        trailing: toggle ?? const SizedBox(width: OwnShape.target),
      );
      if (open && !deep) {
        yield* _branch(context, l, node.children, depth + 1, viewActive);
      }
    }
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text, {this.caption});
  final String text;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final colors = context.own;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        OwnSpace.xl,
        OwnSpace.s,
        OwnSpace.xl,
        OwnSpace.xs,
      ),
      child: Semantics(
        header: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(text, style: theme.titleSmall),
            if (caption != null)
              Text(
                caption!,
                style: theme.bodySmall?.copyWith(color: colors.textSecondary),
              ),
          ],
        ),
      ),
    );
  }
}

/// One destination or category: a 24 px outlined icon, a wrapping label, the
/// count and an optional trailing control. Selection shows an accent edge.
class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
    this.depth = 0,
    this.trailing,
    this.semanticLabel,
  });

  final IconData icon;
  final String label;
  final int? count;
  final bool selected;
  final VoidCallback onTap;
  final int depth;
  final Widget? trailing;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.own;
    final theme = Theme.of(context).textTheme;
    final fg = selected ? colors.onSelected : colors.text;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: OwnSpace.m),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(OwnShape.navItemRadius),
        child: Material(
          color: selected ? colors.selected : Colors.transparent,
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  selected: selected,
                  button: true,
                  label:
                      semanticLabel ??
                      (count == null ? label : '$label, $count'),
                  excludeSemantics: true,
                  onTap: onTap,
                  child: InkWell(
                    onTap: onTap,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(
                            width: 4,
                            color: selected
                                ? colors.accent
                                : Colors.transparent,
                          ),
                        ),
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minHeight: OwnShape.target,
                        ),
                        child: Padding(
                          padding: EdgeInsetsDirectional.only(
                            start: OwnSpace.m - 4 + depth * 16.0,
                            top: OwnSpace.s,
                            bottom: OwnSpace.s,
                          ),
                          child: Row(
                            children: [
                              Icon(icon, color: fg),
                              const SizedBox(width: OwnSpace.m),
                              Expanded(
                                child: Text(
                                  label,
                                  style: theme.bodyLarge?.copyWith(
                                    color: fg,
                                    fontWeight: selected
                                        ? FontWeight.w600
                                        : null,
                                  ),
                                ),
                              ),
                              if (count != null)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: OwnSpace.s,
                                  ),
                                  child: Text(
                                    '$count',
                                    style: theme.bodyMedium?.copyWith(
                                      color: selected
                                          ? colors.onSelected
                                          : colors.textSecondary,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              ?(trailing ??
                  (count != null
                      ? const SizedBox(width: OwnShape.target)
                      : null)),
            ],
          ),
        ),
      ),
    );
  }
}
