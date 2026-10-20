import 'package:flutter/material.dart';

/// Colour roles of the redesign (spec section 3.3). All values are opaque.
@immutable
class OwnColors extends ThemeExtension<OwnColors> {
  const OwnColors({
    required this.canvas,
    required this.document,
    required this.raised,
    required this.text,
    required this.textSecondary,
    required this.outline,
    required this.divider,
    required this.accent,
    required this.onAccent,
    required this.selected,
    required this.onSelected,
    required this.error,
    required this.errorContainer,
    required this.success,
    required this.successContainer,
    required this.decision,
    required this.decisionContainer,
    required this.info,
    required this.infoContainer,
  });

  static const light = OwnColors(
    canvas: Color(0xFFFAF8F3),
    document: Color(0xFFFFFEFA),
    raised: Color(0xFFF0EDE6),
    text: Color(0xFF25251F),
    textSecondary: Color(0xFF5C5C52),
    outline: Color(0xFF78786C),
    divider: Color(0xFFD7D4CC),
    accent: Color(0xFF805400),
    onAccent: Color(0xFFFFFFFF),
    selected: Color(0xFFFFDEA6),
    onSelected: Color(0xFF392800),
    error: Color(0xFFB12C2C),
    errorContainer: Color(0xFFFCE8E6),
    success: Color(0xFF24634D),
    successContainer: Color(0xFFE0F3E8),
    decision: Color(0xFF7C4500),
    decisionContainer: Color(0xFFFFE7CE),
    info: Color(0xFF255E89),
    infoContainer: Color(0xFFE4EFF9),
  );

  static const dark = OwnColors(
    canvas: Color(0xFF171714),
    document: Color(0xFF20201C),
    raised: Color(0xFF2A2A24),
    text: Color(0xFFEEEDE5),
    textSecondary: Color(0xFFC1C1B4),
    outline: Color(0xFF8F9082),
    divider: Color(0xFF3D3D36),
    accent: Color(0xFFE9BE74),
    onAccent: Color(0xFF322100),
    selected: Color(0xFF493715),
    onSelected: Color(0xFFFFDEA6),
    error: Color(0xFFFFB4AB),
    errorContainer: Color(0xFF4D2323),
    success: Color(0xFF91D5B3),
    successContainer: Color(0xFF183C2D),
    decision: Color(0xFFFFBE80),
    decisionContainer: Color(0xFF462C15),
    info: Color(0xFFA4C9ED),
    infoContainer: Color(0xFF19364D),
  );

  final Color canvas;
  final Color document;

  /// Raised surface and toolbar.
  final Color raised;

  /// Primary text.
  final Color text;

  /// Secondary text and Markdown markers.
  final Color textSecondary;

  /// Control outline; meaningful boundaries need 3:1.
  final Color outline;

  /// Decorative hairline between rows; not a control boundary.
  final Color divider;
  final Color accent;
  final Color onAccent;
  final Color selected;
  final Color onSelected;
  final Color error;
  final Color errorContainer;
  final Color success;
  final Color successContainer;
  final Color decision;
  final Color decisionContainer;
  final Color info;
  final Color infoContainer;

  Color foreground(OwnTone tone) => switch (tone) {
    OwnTone.neutral => textSecondary,
    OwnTone.error => error,
    OwnTone.success => success,
    OwnTone.decision => decision,
    OwnTone.info => info,
  };

  Color container(OwnTone tone) => switch (tone) {
    OwnTone.neutral => raised,
    OwnTone.error => errorContainer,
    OwnTone.success => successContainer,
    OwnTone.decision => decisionContainer,
    OwnTone.info => infoContainer,
  };

  @override
  OwnColors copyWith({
    Color? canvas,
    Color? document,
    Color? raised,
    Color? text,
    Color? textSecondary,
    Color? outline,
    Color? divider,
    Color? accent,
    Color? onAccent,
    Color? selected,
    Color? onSelected,
    Color? error,
    Color? errorContainer,
    Color? success,
    Color? successContainer,
    Color? decision,
    Color? decisionContainer,
    Color? info,
    Color? infoContainer,
  }) => OwnColors(
    canvas: canvas ?? this.canvas,
    document: document ?? this.document,
    raised: raised ?? this.raised,
    text: text ?? this.text,
    textSecondary: textSecondary ?? this.textSecondary,
    outline: outline ?? this.outline,
    divider: divider ?? this.divider,
    accent: accent ?? this.accent,
    onAccent: onAccent ?? this.onAccent,
    selected: selected ?? this.selected,
    onSelected: onSelected ?? this.onSelected,
    error: error ?? this.error,
    errorContainer: errorContainer ?? this.errorContainer,
    success: success ?? this.success,
    successContainer: successContainer ?? this.successContainer,
    decision: decision ?? this.decision,
    decisionContainer: decisionContainer ?? this.decisionContainer,
    info: info ?? this.info,
    infoContainer: infoContainer ?? this.infoContainer,
  );

  @override
  OwnColors lerp(OwnColors? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return OwnColors(
      canvas: mix(canvas, other.canvas),
      document: mix(document, other.document),
      raised: mix(raised, other.raised),
      text: mix(text, other.text),
      textSecondary: mix(textSecondary, other.textSecondary),
      outline: mix(outline, other.outline),
      divider: mix(divider, other.divider),
      accent: mix(accent, other.accent),
      onAccent: mix(onAccent, other.onAccent),
      selected: mix(selected, other.selected),
      onSelected: mix(onSelected, other.onSelected),
      error: mix(error, other.error),
      errorContainer: mix(errorContainer, other.errorContainer),
      success: mix(success, other.success),
      successContainer: mix(successContainer, other.successContainer),
      decision: mix(decision, other.decision),
      decisionContainer: mix(decisionContainer, other.decisionContainer),
      info: mix(info, other.info),
      infoContainer: mix(infoContainer, other.infoContainer),
    );
  }
}

/// Semantic tone of a banner, state line or status; always paired with text
/// and an icon, never colour alone.
enum OwnTone { neutral, error, success, decision, info }

/// Spacing scale (spec 3.6).
abstract final class OwnSpace {
  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double huge = 48;

  /// Phone horizontal inset; login uses [loginInset].
  static const double phoneInset = 16;
  static const double loginInset = 20;
  static const double tabletPaneInset = 24;
}

/// Corner radii and sizes (spec 3.6).
abstract final class OwnShape {
  static const double compactRadius = 8;
  static const double controlRadius = 14;
  static const double navItemRadius = 12;
  static const double sheetRadius = 24;

  /// Minimum size of every shared touch target.
  static const double target = 48;
  static const double icon = 24;

  /// Maximum width of the writing column.
  static const double editorMeasure = 720;

  /// Forms stay in this width range on large windows.
  static const double formWidth = 560;
  static const double focusRing = 2;
}

/// Durations (spec 3.6). Use [OwnMotion.of] to honour reduced motion.
abstract final class OwnMotion {
  static const press = Duration(milliseconds: 100);
  static const inlineExpand = Duration(milliseconds: 160);
  static const pane = Duration(milliseconds: 220);
  static const sheetIn = Duration(milliseconds: 280);
  static const sheetOut = Duration(milliseconds: 200);
  static const previewCrossfade = Duration(milliseconds: 120);

  /// [normal], or zero when the system asks to remove animations.
  static Duration of(BuildContext context, Duration normal) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : normal;
}

extension OwnThemeContext on BuildContext {
  /// The colour roles of the active theme; the light roles when the app runs
  /// without [OwnTheme] so shared widgets still render.
  OwnColors get own =>
      Theme.of(this).extension<OwnColors>() ??
      (Theme.of(this).brightness == Brightness.dark
          ? OwnColors.dark
          : OwnColors.light);
}
