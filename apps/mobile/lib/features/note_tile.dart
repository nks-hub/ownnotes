import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:intl/intl.dart';
import '../design/design.dart';
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

/// The labeled state lines of a row in priority order: decision, then
/// unavailable, then pending work, then sharing (spec 4.1). One line each,
/// never a dense badge row.
List<NoteStateLine> noteStateLines(AppLocalizations l, NoteRow row) {
  final note = row.note;
  return [
    if (note.syncState == 'needsDecision')
      NoteStateLine(
        text: l.rowNeedsDecision,
        icon: Icons.rule,
        tone: OwnTone.decision,
      ),
    if (row.unavailable)
      NoteStateLine(
        text: l.rowUnavailable,
        icon: Icons.sync_problem_outlined,
        tone: OwnTone.error,
      ),
    if (row.missing)
      NoteStateLine(
        text: l.rowMissing,
        icon: Icons.cloud_off_outlined,
        tone: OwnTone.error,
      ),
    if (note.syncState == 'draft')
      NoteStateLine(text: l.rowSavedWaiting, icon: Icons.schedule),
    if (note.syncState == 'sending')
      NoteStateLine(text: l.rowUploading, icon: Icons.cloud_upload_outlined),
    if (row.isIncoming)
      NoteStateLine(
        text: note.readonly ? l.rowSharedView : l.rowSharedEdit,
        icon: Icons.group_outlined,
      ),
    if (note.sharedByMe == true)
      NoteStateLine(text: l.rowSharedByYou, icon: Icons.share_outlined),
  ];
}

/// One list row: the design frame plus a visible row menu (the alternative
/// to swipe and long press) and, for an unavailable note, a Retry action.
class NoteTile extends StatelessWidget {
  const NoteTile({
    super.key,
    required this.row,
    required this.showCategory,
    required this.onTap,
    this.onLongPress,
    this.onMenu,
    this.onRetry,
    this.selected = false,
    this.customActions = const {},
  });

  final NoteRow row;
  final bool showCategory;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  /// Opens the row menu; null hides the button, as in selection mode.
  final VoidCallback? onMenu;
  final VoidCallback? onRetry;
  final bool selected;

  /// Screen reader alternatives to the swipe gestures.
  final Map<CustomSemanticsAction, VoidCallback> customActions;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = context.own;
    final note = row.note;
    final title = row.title.isEmpty ? l.untitled : row.title;
    final meta = [
      relativeTime(
        l,
        DateTime.fromMillisecondsSinceEpoch(note.updatedAt),
        DateTime.now(),
        Localizations.localeOf(context).toString(),
      ),
      if (showCategory && note.category.isNotEmpty) note.category,
      if (row.tasksTotal > 0) l.tasksDone(row.tasksDone, row.tasksTotal),
      if (row.attachmentCount > 0) l.attachmentsCount(row.attachmentCount),
    ];
    final states = noteStateLines(l, row);
    final label = [
      title,
      if (note.favorite) l.favorite,
      if (row.excerpt.isNotEmpty) row.excerpt,
      for (final s in states) s.text,
      ...meta,
    ].join('. ');
    final frame = OwnNoteRowFrame(
      title: title,
      excerpt: row.excerpt,
      meta: meta,
      stateLines: states,
      favorite: note.favorite,
      favoriteLabel: l.favorite,
      decision: note.syncState == 'needsDecision',
      selected: selected,
      semanticLabel: label,
      onTap: onTap,
      onLongPress: onLongPress,
    );
    // The menu column sits beside the frame, not inside it, so the frame
    // keeps its own selection and divider drawing.
    Widget tile = onMenu == null
        ? frame
        : Stack(
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.only(end: OwnShape.target),
                child: frame,
              ),
              PositionedDirectional(
                end: 0,
                top: 0,
                bottom: 0,
                width: OwnShape.target,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: selected ? colors.selected : null,
                    border: Border(bottom: BorderSide(color: colors.divider)),
                  ),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Semantics(
                      button: true,
                      label: l.rowMenu(title),
                      excludeSemantics: true,
                      onTap: onMenu,
                      // A plain ink target: a tooltip and an IconButton per
                      // row cost visible frames while scrolling.
                      child: InkResponse(
                        onTap: onMenu,
                        radius: OwnShape.target / 2,
                        child: SizedBox.square(
                          dimension: OwnShape.target,
                          child: Icon(
                            Icons.more_vert,
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
    if (onRetry != null && row.unavailable) {
      tile = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          tile,
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: colors.divider)),
            ),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: OwnSpace.s),
                child: OwnButton.text(
                  label: l.retry,
                  icon: Icons.refresh,
                  onPressed: onRetry,
                ),
              ),
            ),
          ),
        ],
      );
    }
    return customActions.isEmpty
        ? tile
        : Semantics(customSemanticsActions: customActions, child: tile);
  }
}
