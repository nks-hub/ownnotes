import 'package:flutter/material.dart';
import '../tokens.dart';

enum OwnButtonKind { primary, secondary, text, destructive }

/// A button with a 48 px minimum height and a wrapping label. The label is
/// never ellipsised; [fullWidth] stretches it for stacked layouts.
class OwnButton extends StatelessWidget {
  const OwnButton({
    required this.label,
    required this.onPressed,
    this.kind = OwnButtonKind.primary,
    this.icon,
    this.fullWidth = false,
    super.key,
  });

  const OwnButton.primary({
    required String label,
    required VoidCallback? onPressed,
    IconData? icon,
    bool fullWidth = false,
    Key? key,
  }) : this(
         label: label,
         onPressed: onPressed,
         icon: icon,
         fullWidth: fullWidth,
         key: key,
       );

  const OwnButton.secondary({
    required String label,
    required VoidCallback? onPressed,
    IconData? icon,
    bool fullWidth = false,
    Key? key,
  }) : this(
         label: label,
         onPressed: onPressed,
         kind: OwnButtonKind.secondary,
         icon: icon,
         fullWidth: fullWidth,
         key: key,
       );

  const OwnButton.text({
    required String label,
    required VoidCallback? onPressed,
    IconData? icon,
    bool fullWidth = false,
    Key? key,
  }) : this(
         label: label,
         onPressed: onPressed,
         kind: OwnButtonKind.text,
         icon: icon,
         fullWidth: fullWidth,
         key: key,
       );

  /// For consequential actions such as removing an account from the device.
  const OwnButton.destructive({
    required String label,
    required VoidCallback? onPressed,
    IconData? icon,
    bool fullWidth = false,
    Key? key,
  }) : this(
         label: label,
         onPressed: onPressed,
         kind: OwnButtonKind.destructive,
         icon: icon,
         fullWidth: fullWidth,
         key: key,
       );

  final String label;
  final VoidCallback? onPressed;
  final OwnButtonKind kind;
  final IconData? icon;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final colors = context.own;
    final text = Text(label, textAlign: TextAlign.center);
    final style = switch (kind) {
      OwnButtonKind.destructive => ButtonStyle(
        foregroundColor: WidgetStatePropertyAll(colors.error),
        side: WidgetStateProperty.resolveWith(
          (s) => BorderSide(
            color: s.contains(WidgetState.focused)
                ? colors.accent
                : colors.error,
            width: s.contains(WidgetState.focused) ? OwnShape.focusRing : 1,
          ),
        ),
      ),
      _ => null,
    };
    final Widget button = switch (kind) {
      OwnButtonKind.primary =>
        icon == null
            ? FilledButton(onPressed: onPressed, child: text)
            : FilledButton.icon(
                onPressed: onPressed,
                icon: Icon(icon),
                label: text,
              ),
      OwnButtonKind.secondary || OwnButtonKind.destructive =>
        icon == null
            ? OutlinedButton(onPressed: onPressed, style: style, child: text)
            : OutlinedButton.icon(
                onPressed: onPressed,
                style: style,
                icon: Icon(icon),
                label: text,
              ),
      OwnButtonKind.text =>
        icon == null
            ? TextButton(onPressed: onPressed, child: text)
            : TextButton.icon(
                onPressed: onPressed,
                icon: Icon(icon),
                label: text,
              ),
    };
    return fullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Actions of a banner, dialog or form. They sit in a wrapping row; at large
/// text or in a narrow space they stack full width, primary first, so a
/// label never has to be shortened.
class OwnActionBar extends StatelessWidget {
  const OwnActionBar({
    required this.actions,
    this.alignment = WrapAlignment.end,
    this.stackBelow = 360,
    super.key,
  });

  /// In reading order, primary action first.
  final List<Widget> actions;
  final WrapAlignment alignment;

  /// Width below which (or text scale 1.3 and above) the actions stack.
  final double stackBelow;

  @override
  Widget build(BuildContext context) {
    final stacked =
        MediaQuery.textScalerOf(context).scale(16) / 16 >= 1.3 ||
        MediaQuery.sizeOf(context).width < stackBelow;
    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < actions.length; i++) ...[
            if (i > 0) const SizedBox(height: OwnSpace.s),
            actions[i],
          ],
        ],
      );
    }
    return Wrap(
      alignment: alignment,
      spacing: OwnSpace.s,
      runSpacing: OwnSpace.s,
      children: actions,
    );
  }
}
