import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import '../../design/design.dart';
import '../../l10n/app_localizations.dart';
import '../note_rows.dart';
import '../note_tile.dart';
import 'notebook_actions.dart';

/// Callbacks of the note list; each has a visible alternative to the gesture
/// that also triggers it (row menu, selection mode, pull to refresh).
class NoteListActions {
  const NoteListActions({
    required this.onOpen,
    required this.onToggleSelect,
    required this.onMenu,
    required this.onFavorite,
    required this.onMoreSwipe,
    required this.onRetry,
  });
  final ValueChanged<NoteRow> onOpen;
  final ValueChanged<NoteRow> onToggleSelect;
  final ValueChanged<NoteRow> onMenu;
  final ValueChanged<NoteRow> onFavorite;

  /// Leading swipe: offers Move and Delete without ever deleting by itself.
  final ValueChanged<NoteRow> onMoreSwipe;
  final ValueChanged<NoteRow> onRetry;
}

/// The continuous document index. Selection mode turns taps into toggles and
/// removes the swipe actions; outside it a trailing swipe favorites and a
/// leading swipe offers Move and Delete, never a full-swipe deletion.
class NoteListView extends StatelessWidget {
  const NoteListView({
    required this.rows,
    required this.showCategory,
    required this.selected,
    required this.openId,
    required this.controller,
    required this.actions,
    super.key,
  });

  final List<NoteRow> rows;
  final bool showCategory;

  /// Ids in multi-select; non-empty means selection mode.
  final Set<String> selected;

  /// The note shown in the editor pane on wide screens.
  final String? openId;
  final ScrollController controller;
  final NoteListActions actions;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final selecting = selected.isNotEmpty;
    return ListView.builder(
      controller: controller,
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: rows.length,
      itemBuilder: (context, i) {
        final row = rows[i];
        final note = row.note;
        final isSelected = selecting
            ? selected.contains(note.id)
            : openId == note.id;
        final tile = NoteTile(
          key: ValueKey('tile-${note.id}'),
          row: row,
          showCategory: showCategory,
          selected: isSelected,
          onTap: () =>
              selecting ? actions.onToggleSelect(row) : actions.onOpen(row),
          onLongPress: selecting ? null : () => actions.onToggleSelect(row),
          onMenu: selecting ? null : () => actions.onMenu(row),
          onRetry: () => actions.onRetry(row),
          customActions: selecting
              ? const {}
              : {
                  CustomSemanticsAction(
                    label: note.favorite ? l.rowFavoriteOff : l.rowFavoriteOn,
                  ): () =>
                      actions.onFavorite(row),
                  CustomSemanticsAction(label: l.rowMenu(row.title)): () =>
                      actions.onMenu(row),
                },
        );
        if (selecting) return tile;
        return Dismissible(
          key: ValueKey('swipe-${note.id}'),
          dismissThresholds: const {
            DismissDirection.startToEnd: 0.3,
            DismissDirection.endToStart: 0.3,
          },
          background: _SwipeBackground(
            alignment: AlignmentDirectional.centerStart,
            icon: Icons.drive_file_move_outlined,
            label: '${l.moveNote} · ${l.delete}',
          ),
          secondaryBackground: _SwipeBackground(
            alignment: AlignmentDirectional.centerEnd,
            icon: note.favorite ? Icons.star : Icons.star_outline,
            label: note.favorite ? l.rowFavoriteOff : l.rowFavoriteOn,
          ),
          // The row always snaps back; the data change moves it, if at all.
          confirmDismiss: (direction) async {
            if (direction == DismissDirection.endToStart) {
              if (canFavorite(note)) actions.onFavorite(row);
            } else {
              actions.onMoreSwipe(row);
            }
            return false;
          },
          child: tile,
        );
      },
    );
  }
}

class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({
    required this.alignment,
    required this.icon,
    required this.label,
  });
  final AlignmentGeometry alignment;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.own;
    return ColoredBox(
      color: colors.raised,
      child: Align(
        alignment: alignment,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: OwnSpace.l),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: colors.accent),
              const SizedBox(width: OwnSpace.s),
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: colors.text),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
