import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../palette.dart';
import '../tokens.g.dart';
import 'buttons.dart';

/// One top-level workspace of an app: Home, Image, Canvas, Stage...
@immutable
class NithyaMode {
  const NithyaMode({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

/// Pill group of icon buttons that switches between [NithyaMode]s.
class NithyaModeSwitcher extends StatelessWidget {
  const NithyaModeSwitcher({super.key, required this.modes, required this.selected, required this.onSelected});

  final List<NithyaMode> modes;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final p = NithyaPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(NithyaSpace.xs),
      decoration: BoxDecoration(
        color: p.panel,
        borderRadius: BorderRadius.circular(NithyaRadius.pill),
        border: Border.all(color: p.panelBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, m) in modes.indexed)
            Padding(
              padding: EdgeInsets.only(left: i == 0 ? 0 : NithyaSpace.xxs),
              child: NithyaIconButton(
                icon: m.icon,
                label: m.label,
                selected: i == selected,
                onPressed: () => onSelected(i),
              ),
            ),
        ],
      ),
    );
  }
}

/// The app frame: a top bar with the mode switcher on the left, a context title
/// in the centre and [actions] on the right, then [body]. [cornerActions] float
/// over the body's bottom-right corner.
class NithyaShell extends StatelessWidget {
  const NithyaShell({
    super.key,
    required this.modes,
    required this.selectedMode,
    required this.onModeSelected,
    required this.title,
    required this.body,
    this.actions = const [],
    this.cornerActions = const [],
    this.backdrop,
  });

  final List<NithyaMode> modes;
  final int selectedMode;
  final ValueChanged<int> onModeSelected;
  final Widget title;
  final Widget body;
  final List<Widget> actions;
  final List<Widget> cornerActions;

  /// Painted behind the top bar and body. Defaults to a [NithyaBackdrop].
  final Widget? backdrop;

  @override
  Widget build(BuildContext context) {
    final p = NithyaPalette.of(context);
    return Material(
      color: p.background,
      child: Stack(
        fit: StackFit.expand,
        children: [
          backdrop ?? const NithyaBackdrop(),
          Column(
            children: [
              SizedBox(
                height: NithyaSize.topBar,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: NithyaSpace.md),
                  child: NavigationToolbar(
                    leading: NithyaModeSwitcher(modes: modes, selected: selectedMode, onSelected: onModeSelected),
                    middle: DefaultTextStyle(
                      style: NithyaType.heading.toStyle(color: p.foreground),
                      overflow: TextOverflow.ellipsis,
                      child: title,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final (i, a) in actions.indexed)
                          Padding(
                            padding: EdgeInsets.only(left: i == 0 ? 0 : NithyaSpace.sm),
                            child: a,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const Divider(),
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    body,
                    if (cornerActions.isNotEmpty)
                      Positioned(
                        right: NithyaSpace.lg,
                        bottom: NithyaSpace.lg,
                        child: Row(
                          children: [
                            for (final (i, a) in cornerActions.indexed)
                              Padding(
                                padding: EdgeInsets.only(left: i == 0 ? 0 : NithyaSpace.sm),
                                child: a,
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The page background: flat colour, the theme's radial glows, and an optional
/// [photo] quieted by the theme's photo tint and grayscale roles.
class NithyaBackdrop extends StatelessWidget {
  const NithyaBackdrop({super.key, this.photo});

  final ImageProvider? photo;

  static const _grayscale = ColorFilter.matrix([
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    final p = NithyaPalette.of(context);
    Widget? image;
    if (photo != null) {
      image = Image(image: photo!, fit: BoxFit.cover, width: double.infinity, height: double.infinity);
      if (p.photoGrayscale) image = ColorFiltered(colorFilter: _grayscale, child: image);
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(painter: _GlowPainter(p.background, p.glow)),
        if (image != null) ...[image, ColoredBox(color: p.photoTint.withValues(alpha: p.photoTintAlpha))],
      ],
    );
  }
}

class _GlowPainter extends CustomPainter {
  _GlowPainter(this.background, this.glow);

  final Color background;
  final List<NithyaGlow> glow;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = background);
    for (final g in glow) {
      final centre = Offset(size.width * g.x, size.height * g.y);
      final radius = math.max(g.radius, 1.0);
      final colour = g.color.withValues(alpha: g.alpha);
      canvas.drawRect(
        rect,
        Paint()
          ..shader = RadialGradient(
            colors: [colour, colour.withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: centre, radius: radius)),
      );
    }
  }

  @override
  bool shouldRepaint(_GlowPainter old) => old.background != background || old.glow != glow;
}
