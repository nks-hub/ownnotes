import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../l10n/app_localizations.dart';
import 'note_rows.dart';

String relativeTime(
  AppLocalizations l,
  DateTime time,
  DateTime now,
  String locale,
) {
  final age = now.difference(time);
  if (age.inMinutes < 1) return l.relNow;
  if (age.inMinutes < 60) return l.relMinutes(age.inMinutes);
  if (age.inHours < 24) return l.relHours(age.inHours);
  final days = DateTime(
    now.year,
    now.month,
    now.day,
  ).difference(DateTime(time.year, time.month, time.day)).inDays;
  if (days <= 1) return l.relYesterday;
  if (days < 7) return l.relDays(days);
  return DateFormat.yMMMd(locale).format(time);
}

class NoteTile extends StatelessWidget {
  const NoteTile({
    super.key,
    required this.row,
    required this.showCategory,
    required this.onTap,
  });

  final NoteRow row;
  final bool showCategory;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final note = row.note;
    final muted = TextStyle(color: scheme.onSurfaceVariant);
    final state = switch (note.syncState) {
      'draft' => (Icons.cloud_upload_outlined, l.stateWaiting),
      'sending' => (Icons.sync, l.stateSending),
      'needsDecision' => (Icons.warning_amber, l.stateNeedsDecision),
      _ => null,
    };
    final stateColor = note.syncState == 'needsDecision'
        ? scheme.error
        : scheme.onSurfaceVariant;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        row.title.isEmpty ? l.untitled : row.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    if (note.favorite)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Icon(
                          Icons.star,
                          size: 18,
                          color: Colors.amber.shade700,
                          semanticLabel: l.favorite,
                        ),
                      ),
                  ],
                ),
                if (row.excerpt.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      row.excerpt,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.merge(muted),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _Meta(
                        text: relativeTime(
                          l,
                          DateTime.fromMillisecondsSinceEpoch(note.updatedAt),
                          DateTime.now(),
                          Localizations.localeOf(context).toString(),
                        ),
                      ),
                      if (showCategory && note.category.isNotEmpty)
                        _Meta(icon: Icons.folder_outlined, text: note.category),
                      if (row.tasksTotal > 0)
                        _Meta(
                          icon: Icons.checklist,
                          text: '${row.tasksDone}/${row.tasksTotal}',
                          label: l.tasksDone(row.tasksDone, row.tasksTotal),
                        ),
                      if (row.attachments)
                        _Meta(icon: Icons.attach_file, label: l.hasAttachments),
                      if (state != null)
                        _Meta(
                          icon: state.$1,
                          text: state.$2,
                          color: stateColor,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1, indent: 16),
      ],
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({this.icon, this.text, this.label, this.color});
  final IconData? icon;
  final String? text;
  final String? label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = this.color ?? theme.colorScheme.onSurfaceVariant;
    final style = theme.textTheme.labelMedium?.copyWith(color: color);
    return Semantics(
      label: label,
      excludeSemantics: label != null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) Icon(icon, size: 14, color: color),
          if (icon != null && text != null) const SizedBox(width: 4),
          if (text != null) Flexible(child: Text(text!, style: style)),
        ],
      ),
    );
  }
}
