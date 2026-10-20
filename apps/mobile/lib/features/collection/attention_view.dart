import 'package:flutter/material.dart';
import 'package:notes_store/notes_store.dart';
import '../../design/design.dart';
import '../../l10n/app_localizations.dart';
import '../note_rows.dart';
import 'status_area.dart';

/// What the owner can do with an item of the attention feed.
class AttentionActions {
  const AttentionActions({
    required this.onResolve,
    required this.onOpen,
    required this.onRetryDeletion,
    required this.onUndoDeletion,
    required this.onRetryNote,
    required this.onSaveCopy,
  });
  final ValueChanged<AttentionItem> onResolve;
  final ValueChanged<AttentionItem> onOpen;
  final ValueChanged<AttentionItem> onRetryDeletion;
  final ValueChanged<AttentionItem> onUndoDeletion;
  final ValueChanged<AttentionItem> onRetryNote;
  final ValueChanged<AttentionItem> onSaveCopy;
}

/// The "Needs attention" destination: decisions, deletions waiting or
/// failed, notes that cannot be refreshed and local save failures, each with
/// its reason and the actions that lead out of it.
class AttentionList extends StatelessWidget {
  const AttentionList({
    required this.items,
    required this.actions,
    required this.controller,
    super.key,
  });

  final List<AttentionItem> items;
  final AttentionActions actions;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    if (items.isEmpty) {
      return OwnStateView(
        icon: Icons.check_circle_outline,
        tone: OwnTone.success,
        title: l.emptyAttentionTitle,
        message: l.emptyAttentionBody,
      );
    }
    return ListView.builder(
      controller: controller,
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: items.length,
      itemBuilder: (context, i) => _AttentionRow(
        key: ValueKey('${items[i].kind.name}-${items[i].noteId}'),
        item: items[i],
        actions: actions,
      ),
    );
  }
}

class _AttentionRow extends StatelessWidget {
  const _AttentionRow({required this.item, required this.actions, super.key});
  final AttentionItem item;
  final AttentionActions actions;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = context.own;
    final note = item.note;
    final title = note == null
        ? l.untitled
        : (note.title.trim().isNotEmpty
              ? note.title
              : titleFromContent(note.content));
    final shownTitle = title.isEmpty ? l.untitled : title;
    final (line, icon, tone) = switch (item.kind) {
      AttentionKind.saveFailure => (
        l.syncSaveFailure,
        Icons.error_outline,
        OwnTone.error,
      ),
      AttentionKind.decision => (
        l.rowNeedsDecision,
        Icons.rule,
        OwnTone.decision,
      ),
      AttentionKind.failedDeletion => (
        l.rowDeletionFailed(syncReason(item.reason ?? '', l)),
        Icons.delete_outline,
        OwnTone.error,
      ),
      AttentionKind.pendingDeletion => (
        l.rowDeletionWaiting,
        Icons.delete_outline,
        OwnTone.neutral,
      ),
      AttentionKind.missing => (
        l.rowMissing,
        Icons.cloud_off_outlined,
        OwnTone.error,
      ),
      AttentionKind.unreadable => (
        l.rowUnavailable,
        Icons.sync_problem_outlined,
        OwnTone.error,
      ),
    };
    final buttons = <Widget>[
      switch (item.kind) {
        AttentionKind.decision => OwnButton.text(
          label: l.resolveNow,
          icon: Icons.rule,
          onPressed: () => actions.onResolve(item),
        ),
        AttentionKind.failedDeletion => OwnButton.text(
          label: l.retry,
          icon: Icons.refresh,
          onPressed: () => actions.onRetryDeletion(item),
        ),
        AttentionKind.unreadable => OwnButton.text(
          label: l.retry,
          icon: Icons.refresh,
          onPressed: () => actions.onRetryNote(item),
        ),
        _ => const SizedBox.shrink(),
      },
      if (item.kind == AttentionKind.failedDeletion ||
          item.kind == AttentionKind.pendingDeletion)
        OwnButton.text(
          label: l.undoAction,
          icon: Icons.undo,
          onPressed: () => actions.onUndoDeletion(item),
        ),
      if (note != null &&
          (item.kind == AttentionKind.missing ||
              item.kind == AttentionKind.unreadable))
        OwnButton.text(
          label: l.saveCopy,
          icon: Icons.copy_outlined,
          onPressed: () => actions.onSaveCopy(item),
        ),
      if (note != null &&
          item.kind != AttentionKind.decision &&
          item.kind != AttentionKind.pendingDeletion &&
          item.kind != AttentionKind.failedDeletion)
        OwnButton.text(
          label: l.openNote,
          icon: Icons.open_in_new,
          onPressed: () => actions.onOpen(item),
        ),
    ].where((w) => w is! SizedBox).toList();
    final excerpt = note == null
        ? ''
        : noteExcerpt(shownTitle, note.content, maxLength: 120);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OwnNoteRowFrame(
          title: shownTitle,
          excerpt: excerpt,
          stateLines: [NoteStateLine(text: line, icon: icon, tone: tone)],
          decision: item.kind == AttentionKind.decision,
          semanticLabel: [shownTitle, line].join('. '),
          onTap: note == null || item.kind == AttentionKind.pendingDeletion
              ? null
              : () => item.kind == AttentionKind.decision
                    ? actions.onResolve(item)
                    : actions.onOpen(item),
        ),
        if (buttons.isNotEmpty)
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: colors.divider)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: OwnSpace.s),
              child: Wrap(spacing: OwnSpace.s, children: buttons),
            ),
          ),
      ],
    );
  }
}
