import 'package:flutter/material.dart';

import 'palette.dart';
import 'tokens.g.dart';

/// The default palette: the first theme in the token file.
NithyaPalette get nithyaDefaultPalette => nithyaPalettes.values.first;

/// Builds a Material [ThemeData] whose colours, type and shapes come from the
/// Nithya tokens. Widgets read the surface roles with [NithyaPalette.of].
ThemeData nithyaTheme([NithyaPalette? palette]) {
  final p = palette ?? nithyaDefaultPalette;
  final scheme = ColorScheme(
    brightness: p.brightness,
    primary: NithyaAccent.primary,
    onPrimary: NithyaAccent.onPrimary,
    secondary: p.controls,
    onSecondary: p.foreground,
    error: NithyaAccent.danger,
    onError: NithyaAccent.onPrimary,
    surface: p.panel,
    onSurface: p.foreground,
    onSurfaceVariant: p.muted,
    surfaceContainerHighest: p.controls,
    outline: p.controlsBorder,
    outlineVariant: p.divider,
    scrim: p.scrim,
  );
  final text = TextTheme(
    displayLarge: NithyaType.hero.toStyle(),
    headlineMedium: NithyaType.title.toStyle(),
    titleMedium: NithyaType.heading.toStyle(),
    bodyMedium: NithyaType.body.toStyle(),
    bodySmall: NithyaType.caption.toStyle(color: p.muted),
    labelLarge: NithyaType.label.toStyle(),
    labelSmall: NithyaType.overline.toStyle(color: p.muted),
  ).apply(bodyColor: p.foreground, displayColor: p.foreground);

  OutlineInputBorder field(Color c, [double w = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(NithyaRadius.lg),
    borderSide: BorderSide(color: c, width: w),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: p.brightness,
    fontFamily: 'packages/nithya/${NithyaFonts.body}',
    textTheme: text,
    scaffoldBackgroundColor: p.background,
    canvasColor: p.background,
    dividerColor: p.divider,
    dividerTheme: DividerThemeData(color: p.divider, thickness: 1, space: 1),
    splashFactory: NoSplash.splashFactory,
    visualDensity: VisualDensity.standard,
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 400),
      decoration: BoxDecoration(
        color: p.modal,
        borderRadius: BorderRadius.circular(NithyaRadius.md),
        border: Border.all(color: p.panelBorder),
      ),
      textStyle: NithyaType.caption.toStyle(color: p.foreground),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.controls.withValues(alpha: 0.6),
      hintStyle: NithyaType.body.toStyle(color: p.muted),
      contentPadding: const EdgeInsets.symmetric(horizontal: NithyaSpace.lg, vertical: NithyaSpace.md),
      border: field(p.controlsBorder),
      enabledBorder: field(p.controlsBorder),
      focusedBorder: field(NithyaAccent.primary, 1.5),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? NithyaAccent.primary : p.controls,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    scrollbarTheme: ScrollbarThemeData(thumbColor: WidgetStatePropertyAll(p.controlsBorder)),
    extensions: [p],
  );
}
