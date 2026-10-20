import 'package:flutter/material.dart';
import '../tokens.dart';
import 'buttons.dart';
import 'feedback.dart';

/// An explicit sync shows its own row only after this long (spec 4.3).
const explicitSyncRowDelay = Duration(milliseconds: 800);

/// Sync and save states of the vocabulary in spec section 4.4.
enum SyncKind {
  /// "Saving on device…"
  savingLocal,

  /// "Saved on device · 2 waiting"
  savedPending,

  /// "Uploading 2 changes"
  uploading,

  /// "Checking for updates"
  pulling,

  /// "Up to date · checked 10:42"
  upToDate,

  /// "Offline · changes saved on device"
  offline,

  /// "Sign in again · local notes retained"
  authFailure,

  /// "2 notes need your decision"
  conflict,

  /// "Could not save on this device"
  localWriteFailure;

  /// Lower is more urgent: decision, then save or upload failure, then
  /// pending work, then ordinary state (spec 4.1).
  int get priority => switch (this) {
    conflict => 0,
    localWriteFailure => 1,
    authFailure => 2,
    savedPending => 3,
    offline => 4,
    uploading => 5,
    pulling => 6,
    savingLocal => 7,
    upToDate => 8,
  };

  /// Critical failures appear immediately as a persistent banner and survive
  /// restart; everything else is a quiet row.
  bool get persistent =>
      this == conflict || this == localWriteFailure || this == authFailure;

  bool get busy => this == uploading || this == pulling || this == savingLocal;

  OwnTone get tone => switch (this) {
    conflict => OwnTone.decision,
    localWriteFailure || authFailure => OwnTone.error,
    upToDate => OwnTone.success,
    _ => OwnTone.neutral,
  };

  IconData get icon => switch (this) {
    savingLocal => Icons.save_outlined,
    savedPending => Icons.schedule,
    uploading => Icons.cloud_upload_outlined,
    pulling => Icons.cloud_download_outlined,
    upToDate => Icons.cloud_done_outlined,
    offline => Icons.cloud_off_outlined,
    authFailure => Icons.lock_outline,
    conflict => Icons.rule,
    localWriteFailure => Icons.error_outline,
  };
}

class SyncAction {
  const SyncAction(this.label, this.onPressed);
  final String label;
  final VoidCallback onPressed;
}

/// A sync state ready to show: the kind picks tone, icon and persistence; the
/// caller supplies the localized [text] (with counts and times already
/// formatted) and the actions of the vocabulary table.
class SyncPresentation {
  const SyncPresentation({
    required this.kind,
    required this.text,
    this.actions = const [],
  });

  final SyncKind kind;
  final String text;
  final List<SyncAction> actions;

  /// The most urgent of [states] by [SyncKind.priority], or null when empty.
  static SyncPresentation? mostUrgent(Iterable<SyncPresentation> states) {
    SyncPresentation? best;
    for (final s in states) {
      if (best == null || s.kind.priority < best.kind.priority) best = s;
    }
    return best;
  }
}

/// A [SyncPresentation] as a row (quiet states) or a banner (critical ones).
/// Text wraps and the row grows; nothing is ellipsised. Quiet states announce
/// themselves politely, banners assertively through [OwnBanner].
class SyncStatusLine extends StatelessWidget {
  const SyncStatusLine(this.state, {super.key});
  final SyncPresentation state;

  @override
  Widget build(BuildContext context) {
    final kind = state.kind;
    final actions = [
      for (var i = 0; i < state.actions.length; i++)
        i == 0
            ? OwnButton.secondary(
                label: state.actions[i].label,
                onPressed: state.actions[i].onPressed,
              )
            : OwnButton.text(
                label: state.actions[i].label,
                onPressed: state.actions[i].onPressed,
              ),
    ];
    if (kind.persistent) {
      return OwnBanner(
        tone: kind.tone,
        icon: kind.icon,
        message: state.text,
        actions: actions,
      );
    }
    final colors = context.own;
    final fg = colors.foreground(kind.tone);
    return Semantics(
      container: true,
      liveRegion: kind == SyncKind.offline || kind == SyncKind.savedPending,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: OwnShape.target),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: OwnSpace.phoneInset,
            vertical: OwnSpace.s,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  ExcludeSemantics(
                    child: kind.busy
                        ? SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: fg,
                            ),
                          )
                        : Icon(kind.icon, size: 18, color: fg),
                  ),
                  const SizedBox(width: OwnSpace.m),
                  Expanded(
                    child: Text(
                      state.text,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: colors.text),
                    ),
                  ),
                ],
              ),
              // Below the text, so a long action label wraps instead of
              // squeezing the message.
              if (state.actions.isNotEmpty)
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: OwnButton.text(
                    label: state.actions.first.label,
                    onPressed: state.actions.first.onPressed,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
