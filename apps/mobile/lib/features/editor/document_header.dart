import 'package:flutter/material.dart';
import '../../design/design.dart';
import '../../l10n/app_localizations.dart';

/// The title as a heading and the category as a breadcrumb (spec 5.1). Both
/// open the Details surface at their own control. [collapsed] hides the whole
/// header while the body keyboard is open; the widget stays in the tree so
/// the editor below keeps its state and focus.
class DocumentHeader extends StatelessWidget {
  const DocumentHeader({
    required this.title,
    required this.category,
    required this.favorite,
    required this.collapsed,
    required this.onTitle,
    required this.onCategory,
    super.key,
  });

  final String title;
  final String category;
  final bool favorite;
  final bool collapsed;
  final VoidCallback onTitle;
  final VoidCallback onCategory;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = context.own;
    final parts = category
        .split('/')
        .where((p) => p.trim().isNotEmpty)
        .toList();
    final content = Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: OwnShape.editorMeasure),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                button: true,
                label: '${l.title}: ${title.isEmpty ? l.untitled : title}',
                excludeSemantics: true,
                onTap: onTitle,
                child: InkWell(
                  onTap: onTitle,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: OwnShape.target,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              title.isEmpty ? l.untitled : title,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: OwnType.documentTitle.copyWith(
                                color: title.isEmpty
                                    ? colors.textSecondary
                                    : colors.text,
                              ),
                            ),
                          ),
                        ),
                        if (favorite)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Icon(
                              Icons.star,
                              color: colors.accent,
                              semanticLabel: l.favorite,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              Semantics(
                button: true,
                label:
                    '${l.category}: ${parts.isEmpty ? l.uncategorised : parts.join(' / ')}',
                excludeSemantics: true,
                onTap: onCategory,
                child: InkWell(
                  onTap: onCategory,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: OwnShape.target,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.folder_outlined,
                          size: 18,
                          color: colors.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            parts.isEmpty ? l.uncategorised : parts.join(' / '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return ClipRect(
      // No animation: source reflow is never animated (spec 3.5), and a
      // half-collapsed header would squeeze the text field below it.
      child: Align(
        alignment: Alignment.topCenter,
        heightFactor: collapsed ? 0 : 1,
        child: ExcludeFocus(
          excluding: collapsed,
          child: collapsed ? ExcludeSemantics(child: content) : content,
        ),
      ),
    );
  }
}
