import 'package:flutter/material.dart';
import '../tokens.dart';

/// One labeled state of a note row ("Needs your decision", "Saved on device ·
/// Waiting to upload"). It has its own line, wraps instead of ellipsising,
/// and carries an icon so the meaning is not colour alone.
class NoteStateLine extends StatelessWidget {
  const NoteStateLine({
    required this.text,
    required this.icon,
    this.tone = OwnTone.neutral,
    super.key,
  });

  final String text;
  final IconData icon;
  final OwnTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = context.own;
    final fg = colors.foreground(tone);
    return Padding(
      padding: const EdgeInsets.only(top: OwnSpace.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(icon, size: 16, color: fg),
            ),
          ),
          const SizedBox(width: OwnSpace.s),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: fg),
            ),
          ),
        ],
      ),
    );
  }
}

/// Frame of a list row in the continuous document index: title (two lines),
/// excerpt (two lines), wrapping metadata and one line per important state.
/// Height follows the content, never a fixed value. Priority of the
/// [stateLines] (decision, failure, pending, then metadata) is the caller's
/// order. `decision` draws the leading edge; `selected` adds the check and
/// the accent edge.
class OwnNoteRowFrame extends StatelessWidget {
  const OwnNoteRowFrame({
    required this.title,
    required this.semanticLabel,
    this.excerpt,
    this.meta = const [],
    this.stateLines = const [],
    this.favorite = false,
    this.favoriteLabel,
    this.decision = false,
    this.selected = false,
    this.onTap,
    this.onLongPress,
    super.key,
  });

  final String title;
  final String? excerpt;

  /// Category, time, counts: shown as a wrapping row of short strings.
  final List<String> meta;
  final List<NoteStateLine> stateLines;
  final bool favorite;

  /// Localized "Favorite"; the star is announced as part of the row.
  final String? favoriteLabel;
  final bool decision;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Full spoken description in a stable order: title, summary, state, action.
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.own;
    final theme = Theme.of(context).textTheme;
    final edge = decision
        ? colors.decision
        : selected
        ? colors.accent
        : null;
    return Semantics(
      label: semanticLabel,
      selected: selected,
      button: onTap != null,
      excludeSemantics: true,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Material(
        color: selected ? colors.selected : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                left: edge == null
                    ? BorderSide.none
                    : BorderSide(color: edge, width: 4),
                bottom: BorderSide(color: colors.divider),
              ),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: OwnShape.target),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: OwnSpace.phoneInset,
                  vertical: OwnSpace.m,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (selected)
                          Padding(
                            padding: const EdgeInsets.only(right: OwnSpace.s),
                            child: Icon(
                              Icons.check_circle,
                              size: 20,
                              color: colors.accent,
                            ),
                          ),
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.titleSmall?.copyWith(
                              color: selected
                                  ? colors.onSelected
                                  : colors.text,
                            ),
                          ),
                        ),
                        if (favorite)
                          Padding(
                            padding: const EdgeInsets.only(left: OwnSpace.s),
                            child: Icon(
                              Icons.star,
                              size: 20,
                              color: colors.accent,
                              semanticLabel: favoriteLabel,
                            ),
                          ),
                      ],
                    ),
                    if (excerpt != null && excerpt!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: OwnSpace.xs),
                        child: Text(
                          excerpt!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.bodyMedium?.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                    if (meta.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: OwnSpace.xs),
                        child: Wrap(
                          spacing: OwnSpace.m,
                          children: [
                            for (final m in meta)
                              Text(
                                m,
                                style: theme.bodySmall?.copyWith(
                                  color: colors.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ...stateLines,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
