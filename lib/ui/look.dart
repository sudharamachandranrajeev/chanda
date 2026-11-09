import 'dart:math' as math;

import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:nithya/nithya.dart';

// Chanda's look: the Nithya Studio kit. Deep glass-dark panels over a
// softly lit backdrop, cards that stand off the page as raised tiles
// (layered shadows below, a lit edge above), and a glow on what changed:
// a price that dropped, an alert not yet seen. Every movement is a short
// fade or lift, and stops when the system asks for reduced motion.

/// Theme choices: a Nithya palette by name, or 'system' (Daylight by day,
/// Lagoon by night).
const themeChoices = ['system', 'lagoon', 'daylight', 'dusk', 'ember', 'graphite', 'ink'];
const defaultTheme = 'lagoon';

/// Price drops and good news.
const drop = NithyaAccent.success;

/// Things that need the user.
const attention = NithyaAccent.warning;

String themeLabel(String choice) =>
    choice == 'system' ? 'Match system' : nithyaPalettes[choice]?.label ?? choice;

NithyaPalette paletteFor(String choice, Brightness platform) {
  if (choice == 'system') return nithyaPalettes[platform == Brightness.dark ? 'lagoon' : 'daylight']!;
  return nithyaPalettes[choice] ?? nithyaPalettes[defaultTheme]!;
}

/// Chanda's [ThemeData] for one palette: Nithya's colours and type, plus
/// the Material components brahma_core's shared screens use.
ThemeData chandaTheme(NithyaPalette p) {
  final base = nithyaTheme(p);
  final scheme = base.colorScheme.copyWith(
    tertiary: drop,
    surfaceContainerLow: p.panel,
    surfaceContainer: p.panel,
    surfaceContainerHigh: p.controls,
    primaryContainer: NithyaAccent.primary.withValues(alpha: 0.18),
    onPrimaryContainer: p.foreground,
    errorContainer: NithyaAccent.danger.withValues(alpha: 0.25),
    onErrorContainer: p.foreground,
    inverseSurface: p.foreground,
    onInverseSurface: p.background,
  );
  final t = base.textTheme;
  final type = t.copyWith(
    headlineSmall: NithyaType.title.toStyle(color: p.foreground).copyWith(fontSize: 22),
    titleLarge: NithyaType.heading.toStyle(color: p.foreground).copyWith(fontSize: 19),
    titleSmall: NithyaType.label.toStyle(color: p.foreground),
    bodyLarge: NithyaType.body.toStyle(color: p.foreground).copyWith(fontSize: 15),
    labelMedium: NithyaType.label.toStyle(color: p.foreground).copyWith(fontSize: 12),
  );
  const stadium = StadiumBorder();
  final radius = BorderRadius.circular(NithyaRadius.xxl);
  return base.copyWith(
    colorScheme: scheme,
    textTheme: type,
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: p.background,
    pageTransitionsTheme: Motion.pageTransitions,
    splashFactory: InkSparkle.splashFactory,
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leadingAndTrailingTextStyle: type.labelLarge,
      iconColor: p.muted,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: p.foreground,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: type.headlineSmall,
    ),
    cardTheme: CardThemeData(
      color: p.panel.withValues(alpha: 0.92),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: p.panelBorder),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: stadium,
      side: BorderSide(color: p.controlsBorder),
      backgroundColor: p.controls.withValues(alpha: 0.5),
      selectedColor: NithyaAccent.primary.withValues(alpha: 0.22),
      checkmarkColor: NithyaAccent.primary,
      labelStyle: type.labelLarge,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: stadium,
        backgroundColor: NithyaAccent.primary,
        foregroundColor: NithyaAccent.onPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: type.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: stadium,
        foregroundColor: p.foreground,
        side: BorderSide(color: p.controlsBorder),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(shape: stadium, foregroundColor: NithyaAccent.primary),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: NithyaAccent.primary,
      foregroundColor: NithyaAccent.onPrimary,
      shape: stadium,
      elevation: 6,
      highlightElevation: 10,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.panel.withValues(alpha: 0.96),
      surfaceTintColor: Colors.transparent,
      indicatorColor: NithyaAccent.primary.withValues(alpha: 0.22),
      indicatorShape: stadium,
      elevation: 0,
      height: 64,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(color: s.contains(WidgetState.selected) ? NithyaAccent.primary : p.muted),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: Colors.transparent,
      indicatorColor: NithyaAccent.primary.withValues(alpha: 0.2),
      indicatorShape: stadium,
      selectedIconTheme: const IconThemeData(color: NithyaAccent.primary),
      unselectedIconTheme: IconThemeData(color: p.muted),
      selectedLabelTextStyle: type.labelLarge?.copyWith(color: NithyaAccent.primary),
      unselectedLabelTextStyle: type.labelLarge?.copyWith(color: p.muted),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.modal,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: p.panelBorder),
      ),
      titleTextStyle: type.headlineSmall,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.modal,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: p.controlsBorder,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: p.modal,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NithyaRadius.xl),
        side: BorderSide(color: p.panelBorder),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.modal,
      contentTextStyle: type.bodyMedium,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NithyaRadius.xl),
        side: BorderSide(color: p.panelBorder),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: NithyaAccent.primary,
      linearTrackColor: p.controls,
      borderRadius: BorderRadius.circular(8),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        side: BorderSide(color: p.controlsBorder),
        selectedBackgroundColor: NithyaAccent.primary.withValues(alpha: 0.22),
      ),
    ),
  );
}

/// Muted text colour.
Color muted(BuildContext c) => NithyaPalette.of(c).muted;

/// The page behind every screen: the palette's backdrop with its lights.
class Backdrop extends StatelessWidget {
  const Backdrop({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Stack(fit: StackFit.expand, children: [const NithyaBackdrop(), child]);
}

/// A raised tile: the card stands off the page on layered shadows (a
/// short dark edge under it and a long soft one further out), with light
/// catching its top edge. On a pointer it lifts and leans a little towards
/// the cursor; pressed, it settles back. [glow] rings it in a colour.
class Extruded extends StatefulWidget {
  const Extruded({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.glow,
    this.selected = false,
    this.radius = NithyaRadius.xxl,
    this.padding = EdgeInsets.zero,
    this.depth = 1,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? glow;
  final bool selected;
  final double radius;
  final EdgeInsets padding;

  /// How far it stands off the page, 0 to 1.
  final double depth;

  @override
  State<Extruded> createState() => _ExtrudedState();
}

class _ExtrudedState extends State<Extruded> {
  var _hover = false;
  var _down = false;
  var _lean = Offset.zero;

  @override
  Widget build(BuildContext context) {
    final p = NithyaPalette.of(context);
    final still = Motion.reduced(context);
    final dark = p.brightness == Brightness.dark;
    final lift = widget.onTap == null ? 0.0 : (_down ? -0.6 : (_hover ? 1.0 : 0.0));
    final d = widget.depth * (1 + lift * 0.6);
    final shade = Colors.black.withValues(alpha: dark ? 0.55 : 0.16);
    final glow = widget.glow ?? (widget.selected ? NithyaAccent.primary : null);
    final r = BorderRadius.circular(widget.radius);
    final tilt = still
        ? Matrix4.identity()
        : (Matrix4.identity()
            ..setEntry(3, 2, 0.0012)
            ..rotateX(-_lean.dy * 0.05)
            ..rotateY(_lean.dx * 0.05)
            ..translateByDouble(0.0, -3 * lift, 0.0, 1.0));
    final card = AnimatedContainer(
      duration: still ? Duration.zero : NithyaMotion.slow,
      curve: Motion.curve,
      transform: tilt,
      transformAlignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: r,
        color: p.panel,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(p.panel, p.foreground, dark ? 0.05 : 0.0)!, p.panel],
        ),
        border: Border.all(
          color: widget.selected
              ? NithyaAccent.primary
              : Color.lerp(p.panelBorder, p.foreground, _hover ? 0.12 : 0)!,
          width: widget.selected ? 1.6 : 1,
        ),
        boxShadow: [
          // The extrusion: a tight, dark edge just under the tile...
          BoxShadow(color: shade, offset: Offset(0, 2 * d), blurRadius: 2 * d),
          // ...and a long, soft fall-off further down.
          BoxShadow(
            color: shade.withValues(alpha: shade.a * 0.6),
            offset: Offset(0, 14 * d),
            blurRadius: 30 * d,
            spreadRadius: -6,
          ),
          if (glow != null)
            BoxShadow(color: glow.withValues(alpha: dark ? 0.38 : 0.28), blurRadius: 26, spreadRadius: -2),
        ],
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: r,
        // Light along the top edge.
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: const Alignment(0, -0.6),
          colors: [
            Colors.white.withValues(alpha: dark ? 0.07 : 0.5),
            Colors.white.withValues(alpha: 0),
          ],
        ),
      ),
      child: ClipRRect(
        borderRadius: r,
        child: Padding(padding: widget.padding, child: widget.child),
      ),
    );
    if (widget.onTap == null && widget.onLongPress == null) return card;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() {
        _hover = false;
        _lean = Offset.zero;
      }),
      onHover: (e) {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null || !box.hasSize) return;
        final s = box.size;
        setState(
          () => _lean = Offset(
            ((e.localPosition.dx / s.width) * 2 - 1).clamp(-1, 1),
            ((e.localPosition.dy / s.height) * 2 - 1).clamp(-1, 1),
          ),
        );
      },
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: card,
      ),
    );
  }
}

/// A small pill that glows softly, breathing slowly unless motion is
/// reduced: a price drop, an unseen alert.
class GlowBadge extends StatefulWidget {
  const GlowBadge({super.key, required this.label, required this.color, this.icon});
  final String label;
  final Color color;
  final IconData? icon;

  @override
  State<GlowBadge> createState() => _GlowBadgeState();
}

class _GlowBadgeState extends State<GlowBadge> with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _pulse.value = 0.5;
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.color;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_pulse.value);
        return DecoratedBox(
          decoration: BoxDecoration(
            // Dark under the tint, so it reads on a light picture too.
            color: Color.alphaBlend(c.withValues(alpha: 0.22), const Color(0xD90B1018)),
            borderRadius: BorderRadius.circular(NithyaRadius.pill),
            border: Border.all(color: c.withValues(alpha: 0.55)),
            boxShadow: [
              BoxShadow(
                color: c.withValues(alpha: 0.18 + 0.22 * t),
                blurRadius: 8 + 10 * t,
              ),
            ],
          ),
          child: child,
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.icon != null) ...[Icon(widget.icon, size: 13, color: c), const SizedBox(width: 3)],
            Flexible(
              child: Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: NithyaType.label
                    .toStyle(color: c)
                    .copyWith(fontSize: 11.5, fontFeatures: tabular.fontFeatures),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A quiet pill: freshness, the shop, a tag.
class Tag extends StatelessWidget {
  const Tag(this.label, {super.key, this.icon, this.color});
  final String label;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = NithyaPalette.of(context);
    final c = color ?? p.muted;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: (color ?? p.controls).withValues(alpha: color == null ? 0.7 : 0.14),
        borderRadius: BorderRadius.circular(NithyaRadius.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 12, color: c), const SizedBox(width: 3)],
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: NithyaType.caption.toStyle(color: c).copyWith(fontSize: 11.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Text that glows: the price on an item's own page.
class GlowText extends StatelessWidget {
  const GlowText(this.text, {super.key, required this.style, this.color});
  final String text;
  final TextStyle style;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? style.color ?? NithyaPalette.of(context).foreground;
    return Text(
      text,
      style: style.copyWith(
        color: c,
        fontFeatures: tabular.fontFeatures,
        shadows: [Shadow(color: c.withValues(alpha: 0.45), blurRadius: 18)],
      ),
    );
  }
}

/// Grid columns for tiles at least [min] wide.
int columnsFor(double width, {double min = 240}) => math.max(1, (width / min).floor());
