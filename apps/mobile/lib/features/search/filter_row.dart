import 'package:flutter/material.dart';
import '../../design/design.dart';
import '../../l10n/app_localizations.dart';
import 'search_filters.dart';

/// The wrapping row of quick filters under the search field (spec 4.3). It
/// wraps instead of scrolling so no filter hides at large text.
class FilterRow extends StatelessWidget {
  const FilterRow({
    required this.filters,
    required this.onChanged,
    this.scopeLabel,
    this.onClearScope,
    super.key,
  });

  final NoteFilters filters;
  final ValueChanged<NoteFilters> onChanged;

  /// Name of the category or destination the search is limited to.
  final String? scopeLabel;
  final VoidCallback? onClearScope;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final active = !filters.isEmpty;
    Widget chip(String label, bool value, NoteFilters Function(bool) apply) =>
        FilterChip(
          label: Text(label),
          selected: value,
          showCheckmark: true,
          onSelected: (v) => onChanged(apply(v)),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        OwnSpace.phoneInset,
        OwnSpace.s,
        OwnSpace.phoneInset,
        OwnSpace.xs,
      ),
      child: Wrap(
        spacing: OwnSpace.s,
        children: [
          if (scopeLabel != null)
            InputChip(
              avatar: const Icon(Icons.folder_outlined),
              label: Text(scopeLabel!),
              onDeleted: onClearScope,
              deleteButtonTooltipMessage: l.clearFilters,
            ),
          chip(
            l.favorites,
            filters.favorites,
            (v) => filters.copyWith(favorites: v),
          ),
          chip(
            l.filterTasks,
            filters.unfinishedTasks,
            (v) => filters.copyWith(unfinishedTasks: v),
          ),
          chip(
            l.filterAttachments,
            filters.attachments,
            (v) => filters.copyWith(attachments: v),
          ),
          if (active)
            TextButton(
              onPressed: () => onChanged(NoteFilters.none),
              child: Text(l.clearFilters),
            ),
        ],
      ),
    );
  }
}
