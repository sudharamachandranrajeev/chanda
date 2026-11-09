import 'package:flutter/material.dart';

import '../palette.dart';
import '../tokens.g.dart';
import 'buttons.dart';

/// Rounded panel surface. With a [title] it gets a header row holding
/// [actions] and, when [onClose] is set, a close button.
class NithyaPanel extends StatelessWidget {
  const NithyaPanel({
    super.key,
    required this.child,
    this.title,
    this.actions = const [],
    this.onClose,
    this.padding = const EdgeInsets.all(NithyaSpace.lg),
  });

  final Widget child;
  final String? title;
  final List<Widget> actions;
  final VoidCallback? onClose;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final p = NithyaPalette.of(context);
    return Container(
      decoration: BoxDecoration(
        color: p.panel,
        borderRadius: BorderRadius.circular(NithyaRadius.xl),
        border: Border.all(color: p.panelBorder),
        boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 24, offset: Offset(0, 8))],
      ),
      padding: padding,
      child: title == null
          ? child
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(title!, style: NithyaType.heading.toStyle(color: p.foreground)),
                      ),
                    ),
                    ...actions,
                    if (onClose != null)
                      NithyaIconButton(icon: Icons.close_rounded, label: 'Close', onPressed: onClose, size: 30),
                  ],
                ),
                const SizedBox(height: NithyaSpace.md),
                Flexible(child: child),
              ],
            ),
    );
  }
}

/// Floating horizontal group of tool buttons, separated by [NithyaToolbarDivider]s.
class NithyaToolbar extends StatelessWidget {
  const NithyaToolbar({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = NithyaPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(NithyaSpace.xs + 2),
      decoration: BoxDecoration(
        color: p.panel.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(NithyaRadius.lg),
        border: Border.all(color: p.panelBorder),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, spacing: NithyaSpace.xs, children: children),
    );
  }
}

class NithyaToolbarDivider extends StatelessWidget {
  const NithyaToolbarDivider({super.key});

  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 20,
    margin: const EdgeInsets.symmetric(horizontal: NithyaSpace.xs),
    color: NithyaPalette.of(context).controlsBorder,
  );
}

/// Pill-shaped segmented control (e.g. Build / Record).
class NithyaSegmented<T> extends StatelessWidget {
  const NithyaSegmented({super.key, required this.segments, required this.value, required this.onChanged});

  final Map<T, String> segments;
  final T value;
  final ValueChanged<T> onChanged;

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
          for (final MapEntry(key: k, value: label) in segments.entries)
            Semantics(
              selected: k == value,
              button: true,
              child: GestureDetector(
                onTap: () => onChanged(k),
                child: AnimatedContainer(
                  duration: NithyaMotion.base,
                  padding: const EdgeInsets.symmetric(horizontal: NithyaSpace.xl - 2, vertical: NithyaSpace.sm - 1),
                  decoration: BoxDecoration(
                    color: k == value ? p.foreground : Colors.transparent,
                    borderRadius: BorderRadius.circular(NithyaRadius.pill),
                  ),
                  child: Text(label, style: NithyaType.label.toStyle(color: k == value ? p.background : p.muted)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Box with a dashed rounded border.
class NithyaDashedBox extends StatelessWidget {
  const NithyaDashedBox({super.key, required this.child, this.radius = NithyaRadius.xl, this.color});

  final Widget child;
  final double radius;
  final Color? color;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _DashedPainter(color ?? NithyaPalette.of(context).controlsBorder, radius), child: child);
}

class _DashedPainter extends CustomPainter {
  _DashedPainter(this.color, this.radius);

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()..addRRect(RRect.fromRectAndRadius((Offset.zero & size).deflate(0.75), Radius.circular(radius)));
    for (final metric in path.computeMetrics()) {
      for (double d = 0; d < metric.length; d += 10) {
        canvas.drawPath(metric.extractPath(d, d + 5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedPainter old) => old.color != color || old.radius != radius;
}

/// Empty-state drop target: big tinted icon, title, hint and [actions].
class NithyaDropZone extends StatelessWidget {
  const NithyaDropZone({super.key, required this.icon, required this.title, this.hint, this.actions = const []});

  final IconData icon;
  final String title;
  final String? hint;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final p = NithyaPalette.of(context);
    return NithyaDashedBox(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(NithyaSpace.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  color: NithyaAccent.primary.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(NithyaRadius.xxl),
                  border: Border.all(color: NithyaAccent.primary.withValues(alpha: 0.45)),
                ),
                child: Icon(icon, size: 36, color: p.foreground),
              ),
              const SizedBox(height: NithyaSpace.xl),
              Text(title, style: NithyaType.title.toStyle(color: p.foreground)),
              if (hint != null) ...[
                const SizedBox(height: NithyaSpace.sm),
                Text(
                  hint!,
                  textAlign: TextAlign.center,
                  style: NithyaType.body.toStyle(color: p.muted),
                ),
              ],
              if (actions.isNotEmpty) ...[
                const SizedBox(height: NithyaSpace.xl),
                Wrap(
                  spacing: NithyaSpace.md,
                  runSpacing: NithyaSpace.md,
                  alignment: WrapAlignment.center,
                  children: actions,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Selectable tile for pickers (canvas sizes, presets).
class NithyaSelectTile extends StatelessWidget {
  const NithyaSelectTile({
    super.key,
    required this.selected,
    required this.onTap,
    required this.label,
    required this.child,
  });

  final bool selected;
  final VoidCallback onTap;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = NithyaPalette.of(context);
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: NithyaMotion.fast,
          padding: const EdgeInsets.all(NithyaSpace.md),
          decoration: BoxDecoration(
            color: selected ? NithyaAccent.primary.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(NithyaRadius.lg),
            border: Border.all(color: selected ? NithyaAccent.primary : p.panelBorder, width: selected ? 1.5 : 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              child,
              const SizedBox(height: NithyaSpace.sm),
              Text(label, style: NithyaType.caption.toStyle(color: p.foreground)),
            ],
          ),
        ),
      ),
    );
  }
}
