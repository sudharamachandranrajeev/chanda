import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// One soft radial light painted behind a gradient theme.
///
/// [x] and [y] place the centre as a fraction of the backdrop (values outside
/// 0..1 sit off-screen), [radius] is in logical pixels.
@immutable
class NithyaGlow {
  const NithyaGlow({required this.color, required this.alpha, required this.x, required this.y, required this.radius});

  final Color color;
  final double alpha;
  final double x;
  final double y;
  final double radius;
}

/// A text style token. [toStyle] resolves it against the package fonts.
@immutable
class NithyaTypeSpec {
  const NithyaTypeSpec({
    required this.family,
    required this.size,
    required this.weight,
    required this.tracking,
    required this.height,
  });

  final String family;
  final double size;
  final FontWeight weight;
  final double tracking;
  final double height;

  TextStyle toStyle({Color? color}) => TextStyle(
    fontFamily: family,
    package: 'nithya',
    fontSize: size,
    fontWeight: weight,
    letterSpacing: tracking,
    height: height,
    color: color,
  );
}

/// The surface colour roles of one theme. Read it with `NithyaPalette.of(context)`.
@immutable
class NithyaPalette extends ThemeExtension<NithyaPalette> {
  const NithyaPalette({
    required this.name,
    required this.label,
    required this.brightness,
    required this.background,
    required this.panel,
    required this.panelBorder,
    required this.modal,
    required this.controls,
    required this.controlsBorder,
    required this.foreground,
    required this.muted,
    required this.divider,
    required this.scrim,
    required this.scrimAlpha,
    required this.photoTint,
    required this.photoTintAlpha,
    required this.photoGrayscale,
    required this.glow,
  });

  final String name;
  final String label;
  final Brightness brightness;

  /// Page behind everything.
  final Color background;

  /// Docked and floating panels, cards, the prompt dock.
  final Color panel;
  final Color panelBorder;

  /// Dialog surface.
  final Color modal;

  /// Buttons, inputs, chips and other controls.
  final Color controls;
  final Color controlsBorder;

  final Color foreground;

  /// Secondary text: descriptions, hints, captions.
  final Color muted;
  final Color divider;

  /// Dims the app behind dialogs.
  final Color scrim;
  final double scrimAlpha;

  /// Quiets photo backdrops so foreground text stays readable.
  final Color photoTint;
  final double photoTintAlpha;
  final bool photoGrayscale;

  /// Radial lights for gradient themes; empty for flat themes.
  final List<NithyaGlow> glow;

  static NithyaPalette of(BuildContext context) =>
      Theme.of(context).extension<NithyaPalette>() ??
      (throw StateError('No NithyaPalette in theme; use nithyaTheme()'));

  @override
  NithyaPalette copyWith({Color? background, Color? panel, Color? controls, Color? foreground, Color? muted}) =>
      NithyaPalette(
        name: name,
        label: label,
        brightness: brightness,
        background: background ?? this.background,
        panel: panel ?? this.panel,
        panelBorder: panelBorder,
        modal: modal,
        controls: controls ?? this.controls,
        controlsBorder: controlsBorder,
        foreground: foreground ?? this.foreground,
        muted: muted ?? this.muted,
        divider: divider,
        scrim: scrim,
        scrimAlpha: scrimAlpha,
        photoTint: photoTint,
        photoTintAlpha: photoTintAlpha,
        photoGrayscale: photoGrayscale,
        glow: glow,
      );

  @override
  NithyaPalette lerp(NithyaPalette? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    final near = t < 0.5 ? this : other;
    return NithyaPalette(
      name: near.name,
      label: near.label,
      brightness: near.brightness,
      background: c(background, other.background),
      panel: c(panel, other.panel),
      panelBorder: c(panelBorder, other.panelBorder),
      modal: c(modal, other.modal),
      controls: c(controls, other.controls),
      controlsBorder: c(controlsBorder, other.controlsBorder),
      foreground: c(foreground, other.foreground),
      muted: c(muted, other.muted),
      divider: c(divider, other.divider),
      scrim: c(scrim, other.scrim),
      scrimAlpha: lerpDouble(scrimAlpha, other.scrimAlpha, t)!,
      photoTint: c(photoTint, other.photoTint),
      photoTintAlpha: lerpDouble(photoTintAlpha, other.photoTintAlpha, t)!,
      photoGrayscale: near.photoGrayscale,
      glow: near.glow,
    );
  }
}
