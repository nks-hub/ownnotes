import 'package:flutter/material.dart';
import '../core/markdown/live_styling.dart';

/// Type roles (spec 3.4): size / line height / weight. The interface and the
/// proportional editor use the platform font (Roboto on Android, San
/// Francisco on iOS); only code uses the bundled mono font. Text scaling is
/// never clamped.
abstract final class OwnType {
  static TextStyle _role(double size, double line, FontWeight weight) =>
      TextStyle(
        fontSize: size,
        height: line / size,
        fontWeight: weight,
        letterSpacing: 0,
      );

  static final welcomeTitle = _role(30, 38, FontWeight.w600);
  static final screenTitle = _role(22, 28, FontWeight.w600);
  static final documentTitle = _role(26, 34, FontWeight.w600);
  static final sectionHeading = _role(18, 26, FontWeight.w600);
  static final noteRowTitle = _role(17, 24, FontWeight.w600);
  static final body = _role(16, 24, FontWeight.w400);
  static final button = _role(15, 22, FontWeight.w600);
  static final metadata = _role(13, 19, FontWeight.w400);

  /// Source editor body: 17 px on the 1.6 grid (27.2 px lines). The editor
  /// size preference replaces [sourceSize].
  static const sourceSize = 17.0;
  static final sourceBody = _role(
    sourceSize,
    sourceSize * LiveMarkdownMetrics.gridMultiplier,
    FontWeight.w400,
  );

  /// Preview code block: 16 / 24, upright mono.
  static final previewCode = monoTextStyle().copyWith(
    fontSize: 16,
    height: 24 / 16,
  );

  /// Material text theme built from the roles above. The roles are merged
  /// into [base] so the platform font family it carries is kept.
  static TextTheme textTheme(TextTheme base) {
    TextStyle? m(TextStyle? s, TextStyle role) => s?.merge(role) ?? role;
    return base.copyWith(
      displaySmall: m(base.displaySmall, welcomeTitle),
      headlineMedium: m(base.headlineMedium, documentTitle),
      headlineSmall: m(base.headlineSmall, screenTitle),
      titleLarge: m(base.titleLarge, screenTitle),
      titleMedium: m(base.titleMedium, sectionHeading),
      titleSmall: m(base.titleSmall, noteRowTitle),
      bodyLarge: m(base.bodyLarge, body),
      bodyMedium: m(base.bodyMedium, body),
      bodySmall: m(base.bodySmall, metadata),
      labelLarge: m(base.labelLarge, button),
      labelMedium: m(base.labelMedium, metadata),
      labelSmall: m(base.labelSmall, metadata),
    );
  }
}
