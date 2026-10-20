import 'package:flutter/material.dart';
import '../tokens.dart';
import 'buttons.dart';

/// Empty or error state of a list, search or screen (spec 4.6). Centered,
/// scrollable so large text and short windows never overflow, and always
/// states what happened in text, with the actions that lead out of it.
class OwnStateView extends StatelessWidget {
  const OwnStateView({
    required this.title,
    this.message,
    this.icon,
    this.tone = OwnTone.neutral,
    this.actions = const [],
    super.key,
  });

  const OwnStateView.error({
    required String title,
    String? message,
    List<Widget> actions = const [],
    Key? key,
  }) : this(
         title: title,
         message: message,
         icon: Icons.error_outline,
         tone: OwnTone.error,
         actions: actions,
         key: key,
       );

  final String title;
  final String? message;
  final IconData? icon;
  final OwnTone tone;

  /// Typically one [OwnButton.primary] and optionally a secondary action.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final colors = context.own;
    final theme = Theme.of(context).textTheme;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.all(OwnSpace.xl),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.hasBoundedHeight
                ? (constraints.maxHeight - 2 * OwnSpace.xl).clamp(
                    0,
                    double.infinity,
                  )
                : 0,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: OwnShape.formWidth),
              child: Semantics(
                container: true,
                liveRegion: tone == OwnTone.error,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      ExcludeSemantics(
                        child: Icon(
                          icon,
                          size: 48,
                          color: colors.foreground(tone),
                        ),
                      ),
                      const SizedBox(height: OwnSpace.l),
                    ],
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: theme.titleMedium,
                    ),
                    if (message != null) ...[
                      const SizedBox(height: OwnSpace.s),
                      Text(
                        message!,
                        textAlign: TextAlign.center,
                        style: theme.bodyMedium?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                    if (actions.isNotEmpty) ...[
                      const SizedBox(height: OwnSpace.xl),
                      OwnActionBar(
                        actions: actions,
                        alignment: WrapAlignment.center,
                      ),
                    ],
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
