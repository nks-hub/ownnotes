import 'package:flutter/material.dart';
import '../tokens.dart';
import 'buttons.dart';

/// Default icon of a [tone]. Colour is never the only carrier of meaning.
IconData ownToneIcon(OwnTone tone) => switch (tone) {
  OwnTone.neutral => Icons.info_outline,
  OwnTone.error => Icons.error_outline,
  OwnTone.success => Icons.check_circle_outline,
  OwnTone.decision => Icons.rule,
  OwnTone.info => Icons.info_outline,
};

/// A persistent, actionable failure or decision (spec 6.3). Never depends on a
/// timer. The text wraps, actions go below it, and a decision or error gets a
/// 4 px leading edge in addition to the icon and the text.
class OwnBanner extends StatelessWidget {
  const OwnBanner({
    required this.tone,
    required this.message,
    this.title,
    this.actions = const [],
    this.icon,
    this.busy = false,
    super.key,
  });

  final OwnTone tone;
  final String message;

  /// Optional bold first line, for example the kind of problem.
  final String? title;

  /// Buttons below the message; see [OwnButton].
  final List<Widget> actions;
  final IconData? icon;

  /// Shows a progress indicator instead of the icon.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final colors = context.own;
    final fg = colors.foreground(tone);
    final theme = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      liveRegion: tone == OwnTone.error || tone == OwnTone.decision,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.container(tone),
          border: Border(left: BorderSide(color: fg, width: 4)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(OwnSpace.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: busy
                        ? SizedBox.square(
                            dimension: OwnShape.icon,
                            child: Padding(
                              padding: const EdgeInsets.all(2),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: fg,
                              ),
                            ),
                          )
                        : Icon(icon ?? ownToneIcon(tone), color: fg),
                  ),
                  const SizedBox(width: OwnSpace.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (title != null)
                          Text(
                            title!,
                            style: theme.titleSmall?.copyWith(color: fg),
                          ),
                        Text(
                          message,
                          style: theme.bodyMedium?.copyWith(color: colors.text),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (actions.isNotEmpty) ...[
                const SizedBox(height: OwnSpace.m),
                OwnActionBar(actions: actions),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Snackbar for a completed, reversible action (spec 6.3), for example an
/// Undo after deletion. Replaces a snackbar already showing so they do not
/// queue. Persistent problems use [OwnBanner].
ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showOwnSnackBar(
  BuildContext context,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(seconds: 5),
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  return messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      duration: duration,
      action: actionLabel == null || onAction == null
          ? null
          : SnackBarAction(label: actionLabel, onPressed: onAction),
    ),
  );
}
