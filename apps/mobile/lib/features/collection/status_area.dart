import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:notes_store/notes_store.dart';
import '../../design/design.dart';
import '../../l10n/app_localizations.dart';
import 'providers.dart';

/// Localized reason of a stored sync problem code.
String syncReason(String problem, AppLocalizations l) => switch (problem) {
  'offline' => l.reasonOffline,
  'auth' => l.reasonAuth,
  'locked' => l.reasonLocked,
  'storage_full' => l.reasonStorageFull,
  _ => l.reasonServer,
};

String _clock(BuildContext context, DateTime time) =>
    DateFormat.Hm(Localizations.localeOf(context).toString()).format(time);

/// How long a finished "waiting" row stays as "Up to date" before it
/// collapses, so the header does not jump (spec 4.3).
const statusSettleDelay = Duration(milliseconds: 1200);

/// The collapsing status rows under the app bar. Healthy and idle shows
/// nothing; critical states are persistent banners; pending work and explicit
/// checks are one quiet row that collapses again once the work is done.
class NotebookStatusArea extends StatefulWidget {
  const NotebookStatusArea({
    required this.status,
    required this.reauthRequired,
    required this.saveFailures,
    required this.syncing,
    required this.showChecking,
    required this.downloaded,
    required this.attentionShown,
    required this.onSyncNow,
    required this.onSignIn,
    required this.onOpenAttention,
    super.key,
  });

  final AccountSyncStatus status;
  final bool reauthRequired;

  /// Notes the editor could not keep on this device.
  final int saveFailures;
  final bool syncing;

  /// An explicit sync has run longer than [explicitSyncRowDelay].
  final bool showChecking;

  /// Notes on the device; shown as the truthful count of the first download.
  final int downloaded;

  /// The list already is Needs attention, so its banners would repeat it.
  final bool attentionShown;
  final VoidCallback onSyncNow;
  final VoidCallback onSignIn;
  final VoidCallback onOpenAttention;

  @override
  State<NotebookStatusArea> createState() => _NotebookStatusAreaState();
}

class _NotebookStatusAreaState extends State<NotebookStatusArea> {
  SyncKind? _lastQuiet;
  bool _settled = false;
  Timer? _settle;

  @override
  void dispose() {
    _settle?.cancel();
    super.dispose();
  }

  SyncKind? _quietKind() {
    final s = widget.status;
    final online = s.problem == null;
    if (widget.syncing && s.pendingUploads > 0 && online) {
      return SyncKind.uploading;
    }
    final firstDownload = s.lastCheckedAt == null && online;
    if (widget.syncing && (widget.showChecking || firstDownload)) {
      return SyncKind.pulling;
    }
    if (s.problem == 'offline' && s.pendingUploads > 0) {
      return SyncKind.offline;
    }
    if (online && s.pendingUploads > 0) return SyncKind.savedPending;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final s = widget.status;
    final banners = <Widget>[];
    if (widget.reauthRequired || s.problem == 'auth') {
      banners.add(
        SyncStatusLine(
          SyncPresentation(
            kind: SyncKind.authFailure,
            text: l.syncAuthFailure,
            actions: [SyncAction(l.signInAgain, widget.onSignIn)],
          ),
        ),
      );
    }
    if (s.decisions > 0 && !widget.attentionShown) {
      banners.add(
        SyncStatusLine(
          SyncPresentation(
            kind: SyncKind.conflict,
            text: l.conflictsCount(s.decisions),
            actions: [SyncAction(l.needsAttention, widget.onOpenAttention)],
          ),
        ),
      );
    }
    if (widget.saveFailures > 0 && !widget.attentionShown) {
      banners.add(
        SyncStatusLine(
          SyncPresentation(
            kind: SyncKind.localWriteFailure,
            text: l.syncSaveFailure,
            actions: [SyncAction(l.needsAttention, widget.onOpenAttention)],
          ),
        ),
      );
    }
    if (s.failedDeletions > 0 && !widget.attentionShown) {
      banners.add(
        OwnBanner(
          tone: OwnTone.error,
          icon: Icons.delete_outline,
          message: l.deletionsFailed(s.failedDeletions),
          actions: [
            OwnButton.secondary(
              label: l.reviewItems,
              onPressed: widget.onOpenAttention,
            ),
          ],
        ),
      );
    }
    final problem = s.problem;
    if (problem != null &&
        problem != 'auth' &&
        problem != 'offline' &&
        !widget.syncing) {
      banners.add(
        OwnBanner(
          tone: OwnTone.error,
          icon: Icons.cloud_off_outlined,
          message: syncReason(problem, l),
          actions: [
            OwnButton.secondary(label: l.retry, onPressed: widget.onSyncNow),
          ],
        ),
      );
    }

    final quiet = _quietKind();
    // A finished quiet row lingers briefly as "Up to date", then collapses.
    if (quiet != null) {
      _settle?.cancel();
      _settled = false;
      _lastQuiet = quiet;
    } else if (_lastQuiet != null && !_settled) {
      _settle ??= Timer(statusSettleDelay, () {
        _settle = null;
        if (mounted) {
          setState(() {
            _settled = true;
            _lastQuiet = null;
          });
        }
      });
    }
    Widget? row;
    if (banners.isEmpty || quiet != null) {
      row = _quietRow(context, l, quiet);
    }

    // Two banners at most; the rest is in Needs attention and the sheet.
    final children = [...banners.take(2), ?row];
    return AnimatedSize(
      duration: OwnMotion.of(context, OwnMotion.inlineExpand),
      alignment: Alignment.topCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget? _quietRow(BuildContext context, AppLocalizations l, SyncKind? now) {
    final s = widget.status;
    final kind = now ?? _lastQuiet;
    if (kind == null) return null;
    if (now == null) {
      final at = s.lastCheckedAt;
      return SyncStatusLine(
        SyncPresentation(
          kind: SyncKind.upToDate,
          text: l.syncUpToDate(at == null ? '' : _clock(context, at)),
        ),
      );
    }
    return switch (kind) {
      SyncKind.uploading => SyncStatusLine(
        SyncPresentation(kind: kind, text: l.syncUploading(s.pendingUploads)),
      ),
      SyncKind.pulling => SyncStatusLine(
        SyncPresentation(
          kind: kind,
          text: s.lastCheckedAt == null && widget.downloaded > 0
              ? l.downloadingBody(widget.downloaded)
              : l.checkingForUpdates,
        ),
      ),
      SyncKind.offline => SyncStatusLine(
        SyncPresentation(kind: kind, text: l.syncOffline),
      ),
      _ => SyncStatusLine(
        SyncPresentation(
          kind: SyncKind.savedPending,
          text: l.syncSavedWaiting(s.pendingUploads),
          actions: [SyncAction(l.syncNow, widget.onSyncNow)],
        ),
      ),
    };
  }
}

/// The account line inside the app bar. Tapping it opens the sync details;
/// it carries a small progress or offline mark but never a text row.
class AccountSubtitle extends StatelessWidget {
  const AccountSubtitle({
    required this.name,
    required this.busy,
    required this.offline,
    required this.attention,
    required this.onTap,
    super.key,
  });

  final String name;
  final bool busy;
  final bool offline;
  final bool attention;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = context.own;
    final style = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: colors.textSecondary);
    return Semantics(
      button: true,
      label: l.accountSyncHint(name),
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(OwnShape.compactRadius),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 24),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: style,
                ),
              ),
              if (busy)
                const Padding(
                  padding: EdgeInsets.only(left: OwnSpace.s),
                  child: SizedBox.square(
                    dimension: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else if (offline)
                Padding(
                  padding: const EdgeInsets.only(left: OwnSpace.s),
                  child: Icon(
                    Icons.cloud_off_outlined,
                    size: 14,
                    color: colors.textSecondary,
                  ),
                )
              else if (attention)
                Padding(
                  padding: const EdgeInsets.only(left: OwnSpace.s),
                  child: Icon(
                    Icons.error_outline,
                    size: 14,
                    color: colors.error,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Uploads, downloads, decisions and deletions, each on its own, so one
/// failed note does not hide the rest (spec 4.4).
Future<void> showSyncDetails(
  BuildContext context, {
  required String accountId,
  required VoidCallback onSyncNow,
  required VoidCallback onOpenAttention,
}) {
  final l = AppLocalizations.of(context)!;
  return showOwnSheet<void>(
    context: context,
    title: l.syncDetails,
    builder: (sheet) => _SyncDetails(
      accountId: accountId,
      onSyncNow: () {
        Navigator.of(sheet).pop();
        onSyncNow();
      },
      onOpenAttention: () {
        Navigator.of(sheet).pop();
        onOpenAttention();
      },
    ),
  );
}

class _SyncDetails extends ConsumerWidget {
  const _SyncDetails({
    required this.accountId,
    required this.onSyncNow,
    required this.onOpenAttention,
  });
  final String accountId;
  final VoidCallback onSyncNow;
  final VoidCallback onOpenAttention;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final s = ref.watch(syncStatusProvider(accountId)).valueOrNull;
    if (s == null) return const SizedBox(height: OwnShape.target);
    final checked = s.lastCheckedAt;
    final problem = s.problem;
    final downloads = [
      if (problem != null)
        syncReason(problem, l)
      else if (checked == null)
        l.downloadsNever
      else
        l.syncUpToDate(_clock(context, checked)),
      if (s.unreadable > 0) l.downloadsUnreadable(s.unreadable),
      if (s.missing > 0) l.downloadsMissing(s.missing),
    ];
    final deletions = [
      if (s.pendingDeletions - s.failedDeletions > 0)
        l.deletionsWaiting(s.pendingDeletions - s.failedDeletions),
      if (s.failedDeletions > 0) l.deletionsFailed(s.failedDeletions),
      if (s.pendingDeletions == 0) l.deletionsNone,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Section(
          icon: Icons.cloud_upload_outlined,
          title: l.sheetUploads,
          lines: [
            if (s.pendingUploads > 0)
              l.syncSavedWaiting(s.pendingUploads)
            else
              l.uploadsNone,
          ],
        ),
        _Section(
          icon: Icons.cloud_download_outlined,
          title: l.sheetDownloads,
          lines: downloads,
        ),
        _Section(
          icon: Icons.rule,
          title: l.sheetDecisions,
          lines: [
            if (s.decisions > 0)
              l.conflictsCount(s.decisions)
            else
              l.decisionsNone,
          ],
        ),
        _Section(
          icon: Icons.delete_outline,
          title: l.sheetDeletions,
          lines: deletions,
        ),
        const SizedBox(height: OwnSpace.m),
        OwnActionBar(
          actions: [
            OwnButton.primary(
              label: l.syncNow,
              icon: Icons.sync,
              onPressed: onSyncNow,
            ),
            if (s.needsAttention > 0)
              OwnButton.secondary(
                label: l.needsAttention,
                icon: Icons.error_outline,
                onPressed: onOpenAttention,
              ),
          ],
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.lines,
  });
  final IconData icon;
  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final colors = context.own;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: OwnSpace.s),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(child: Icon(icon, color: colors.textSecondary)),
          const SizedBox(width: OwnSpace.l),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(title, style: theme.titleSmall),
                ),
                for (final line in lines)
                  Text(
                    line,
                    style: theme.bodyMedium?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
