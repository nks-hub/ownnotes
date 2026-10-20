import 'package:flutter/material.dart';
import '../../design/design.dart';
import '../../l10n/app_localizations.dart';
import 'suggestion_controller.dart';
import 'suggestion_model.dart';

/// The suggestion rows: raised surface, subtle boundary, an accent edge on the
/// selected row, rows of at least 48 px and at most five visible.
class SuggestionPopup extends StatelessWidget {
  const SuggestionPopup({
    required this.controller,
    required this.placement,
    required this.onAccept,
    super.key,
  });

  final SuggestionController controller;
  final PopupPlacement placement;
  final ValueChanged<SuggestionItem> onAccept;

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    if (state == null || !controller.isOpen) return const SizedBox.shrink();
    final l = AppLocalizations.of(context)!;
    final colors = context.own;
    final rows = state.items.isEmpty ? 1 : placement.rows;
    final height = rows * suggestionRowHeight;
    final Widget content;
    if (state.items.isEmpty) {
      content = _Message(
        text: state.error ? l.suggestError : l.suggestSearching,
        icon: state.error ? Icons.error_outline : Icons.hourglass_empty,
        busy: state.loading,
      );
    } else {
      content = ListView.builder(
        padding: EdgeInsets.zero,
        itemExtent: suggestionRowHeight,
        itemCount: state.items.length,
        itemBuilder: (context, i) => _Row(
          item: state.items[i],
          selected: i == controller.selected,
          index: i,
          count: state.items.length,
          onTap: () => onAccept(state.items[i]),
        ),
      );
    }
    final card = Material(
      color: colors.raised,
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          placement.compact ? 0 : OwnShape.compactRadius,
        ),
        side: BorderSide(color: colors.outline.withValues(alpha: 0.6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(height: height, child: content),
    );
    final popup = Semantics(
      container: true,
      liveRegion: true,
      label: state.items.isEmpty ? null : l.suggestCount(state.items.length),
      // A key press or tap outside must not close the keyboard.
      child: TextFieldTapRegion(child: card),
    );
    if (placement.compact) {
      return Positioned(left: 0, right: 0, bottom: 0, child: popup);
    }
    return Positioned(
      left: placement.left,
      top: placement.top,
      width: placement.width,
      child: popup,
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.item,
    required this.selected,
    required this.index,
    required this.count,
    required this.onTap,
  });
  final SuggestionItem item;
  final bool selected;
  final int index;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.own;
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context).textTheme;
    final leading = item.glyph != null
        ? CircleAvatar(
            radius: 14,
            backgroundColor: item.id.startsWith('user:')
                ? colors.selected
                : Colors.transparent,
            foregroundColor: colors.onSelected,
            child: Text(
              item.glyph!,
              style: TextStyle(fontSize: item.id.startsWith('emoji:') ? 20 : 14),
            ),
          )
        : Icon(item.icon, color: colors.textSecondary);
    return Semantics(
      button: true,
      selected: selected,
      label: [
        item.title,
        if (item.subtitle != null && item.subtitle!.isNotEmpty) item.subtitle!,
      ].join(', '),
      hint: '${l.suggestInsert}, ${index + 1}/$count',
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: selected ? colors.selected : null,
            border: Border(
              left: BorderSide(
                color: selected ? colors.accent : Colors.transparent,
                width: 4,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                SizedBox.square(dimension: 32, child: Center(child: leading)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.bodyMedium?.copyWith(
                          color: selected ? colors.onSelected : colors.text,
                        ),
                      ),
                      if (item.subtitle != null && item.subtitle!.isNotEmpty)
                        Text(
                          item.subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.bodySmall?.copyWith(
                            color: selected
                                ? colors.onSelected
                                : colors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, required this.icon, required this.busy});
  final String text;
  final IconData icon;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final colors = context.own;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          busy
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(icon, color: colors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
