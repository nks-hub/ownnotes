import 'package:flutter/material.dart';
import 'tokens.dart';
import 'typography.dart';

/// Material 3 themes with the OwnNotes colour roles (spec sections 3.2-3.6).
/// Use as `theme: OwnTheme.light(), darkTheme: OwnTheme.dark()`.
abstract final class OwnTheme {
  static ThemeData light() => _build(OwnColors.light, Brightness.light);
  static ThemeData dark() => _build(OwnColors.dark, Brightness.dark);

  /// Colour scheme mapped from the roles. [OwnColors.canvas] is the surface;
  /// the document colour is the lowest container and the raised surface the
  /// container levels above it.
  static ColorScheme scheme(OwnColors c, Brightness brightness) {
    final light = brightness == Brightness.light;
    return ColorScheme(
      brightness: brightness,
      primary: c.accent,
      onPrimary: c.onAccent,
      primaryContainer: c.selected,
      onPrimaryContainer: c.onSelected,
      secondary: c.textSecondary,
      onSecondary: c.canvas,
      secondaryContainer: c.selected,
      onSecondaryContainer: c.onSelected,
      tertiary: c.info,
      onTertiary: c.canvas,
      tertiaryContainer: c.infoContainer,
      onTertiaryContainer: c.info,
      error: c.error,
      onError: light ? const Color(0xFFFFFFFF) : c.canvas,
      errorContainer: c.errorContainer,
      onErrorContainer: c.error,
      surface: c.canvas,
      onSurface: c.text,
      onSurfaceVariant: c.textSecondary,
      surfaceDim: c.canvas,
      surfaceBright: c.document,
      surfaceContainerLowest: c.document,
      surfaceContainerLow: c.canvas,
      surfaceContainer: c.raised,
      surfaceContainerHigh: c.raised,
      surfaceContainerHighest: c.raised,
      outline: c.outline,
      outlineVariant: c.divider,
      shadow: const Color(0xFF000000),
      scrim: const Color(0xFF000000),
      inverseSurface: c.text,
      onInverseSurface: c.canvas,
      inversePrimary: light ? OwnColors.dark.accent : OwnColors.light.accent,
      surfaceTint: const Color(0x00000000),
    );
  }

  static ThemeData _build(OwnColors c, Brightness brightness) {
    final scheme = OwnTheme.scheme(c, brightness);
    final base = ThemeData(brightness: brightness, useMaterial3: true);
    final text = OwnType.textTheme(
      base.textTheme,
    ).apply(bodyColor: c.text, displayColor: c.text);
    final control = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(OwnShape.controlRadius),
    );
    const buttonSize = Size(64, OwnShape.target);
    const buttonPadding = EdgeInsets.symmetric(horizontal: 20, vertical: 12);
    BorderSide? ring(Set<WidgetState> s, BorderSide? rest) =>
        s.contains(WidgetState.focused)
        ? BorderSide(color: c.accent, width: OwnShape.focusRing)
        : rest;
    final outlineSide = BorderSide(color: c.outline);

    return base.copyWith(
      colorScheme: scheme,
      textTheme: text,
      primaryTextTheme: text,
      scaffoldBackgroundColor: c.canvas,
      canvasColor: c.canvas,
      extensions: [c],
      dividerTheme: DividerThemeData(color: c.divider, space: 1, thickness: 1),
      iconTheme: IconThemeData(color: c.text, size: OwnShape.icon),
      appBarTheme: AppBarTheme(
        backgroundColor: c.canvas,
        foregroundColor: c.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: text.titleLarge,
        iconTheme: IconThemeData(color: c.text, size: OwnShape.icon),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: buttonSize,
          padding: buttonPadding,
          shape: control,
          textStyle: OwnType.button,
          backgroundColor: c.accent,
          foregroundColor: c.onAccent,
          disabledBackgroundColor: c.raised,
          disabledForegroundColor: c.textSecondary,
        ).copyWith(side: WidgetStateProperty.resolveWith((s) => ring(s, null))),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: buttonSize,
          padding: buttonPadding,
          shape: control,
          textStyle: OwnType.button,
          foregroundColor: c.accent,
        ).copyWith(
          side: WidgetStateProperty.resolveWith((s) => ring(s, outlineSide)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: buttonSize,
          padding: buttonPadding,
          shape: control,
          textStyle: OwnType.button,
          foregroundColor: c.accent,
        ).copyWith(side: WidgetStateProperty.resolveWith((s) => ring(s, null))),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size.square(OwnShape.target),
          foregroundColor: c.text,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.accent,
        foregroundColor: c.onAccent,
        elevation: 2,
        shape: control,
      ),
      inputDecorationTheme: InputDecorationTheme(
        labelStyle: TextStyle(color: c.textSecondary),
        helperStyle: OwnType.metadata.copyWith(color: c.textSecondary),
        errorStyle: OwnType.metadata.copyWith(color: c.error),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: OwnSpace.l,
          vertical: OwnSpace.m,
        ),
        enabledBorder: _field(outlineSide),
        disabledBorder: _field(BorderSide(color: c.divider)),
        focusedBorder: _field(BorderSide(color: c.accent, width: 2)),
        errorBorder: _field(BorderSide(color: c.error)),
        focusedErrorBorder: _field(BorderSide(color: c.error, width: 2)),
        border: _field(outlineSide),
      ),
      cardTheme: CardThemeData(
        color: c.document,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(OwnShape.navItemRadius),
          side: BorderSide(color: c.divider),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.document,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(OwnShape.sheetRadius),
        ),
        titleTextStyle: text.titleMedium,
        contentTextStyle: text.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.document,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: c.outline,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(OwnShape.sheetRadius),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.text,
        contentTextStyle: text.bodyMedium?.copyWith(color: c.canvas),
        actionTextColor: brightness == Brightness.light
            ? OwnColors.dark.accent
            : OwnColors.light.accent,
        shape: control,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: c.text,
        textColor: c.text,
        selectedColor: c.onSelected,
        selectedTileColor: c.selected,
        minVerticalPadding: OwnSpace.s,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(OwnShape.navItemRadius),
        ),
      ),
      navigationDrawerTheme: NavigationDrawerThemeData(
        backgroundColor: c.canvas,
        surfaceTintColor: Colors.transparent,
        indicatorColor: c.selected,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(OwnShape.navItemRadius),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.canvas,
        selectedColor: c.selected,
        side: outlineSide,
        labelStyle: OwnType.metadata.copyWith(color: c.text),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(OwnShape.compactRadius),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.accent : null,
        ),
        checkColor: WidgetStatePropertyAll(c.onAccent),
        side: WidgetStateBorderSide.resolveWith(
          (s) => BorderSide(
            color: s.contains(WidgetState.selected) ? c.accent : c.outline,
            width: 2,
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.onAccent : c.outline,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.accent : c.canvas,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.accent : c.outline,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.accent,
        linearTrackColor: c.raised,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: c.text,
          borderRadius: BorderRadius.circular(OwnShape.compactRadius),
        ),
        textStyle: OwnType.metadata.copyWith(color: c.canvas),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.accent,
        selectionColor: c.selected,
        selectionHandleColor: c.accent,
      ),
    );
  }

  static OutlineInputBorder _field(BorderSide side) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(OwnShape.controlRadius),
    borderSide: side,
  );
}
