import 'package:flutter/material.dart';

import '../palette.dart';
import '../tokens.g.dart';

enum NithyaButtonVariant { primary, secondary, ghost, danger }

/// Text button with an optional leading icon. [pill] gives full-round ends
/// (forms, hero actions); the default rounded shape suits toolbars.
class NithyaButton extends StatelessWidget {
  const NithyaButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = NithyaButtonVariant.primary,
    this.pill = false,
    this.large = false,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final NithyaButtonVariant variant;
  final bool pill;
  final bool large;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final p = NithyaPalette.of(context);
    final (bg, fg, border) = switch (variant) {
      NithyaButtonVariant.primary => (NithyaAccent.primary, NithyaAccent.onPrimary, Colors.transparent),
      NithyaButtonVariant.secondary => (p.controls, p.foreground, p.controlsBorder),
      NithyaButtonVariant.ghost => (Colors.transparent, p.foreground, Colors.transparent),
      NithyaButtonVariant.danger => (NithyaAccent.danger, NithyaAccent.onPrimary, Colors.transparent),
    };
    final style = ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.disabled)) return bg.withValues(alpha: bg.a * 0.45);
        if (s.contains(WidgetState.hovered)) return Color.lerp(bg, p.foreground, 0.08);
        return bg;
      }),
      foregroundColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.disabled) ? fg.withValues(alpha: 0.5) : fg,
      ),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      minimumSize: WidgetStatePropertyAll(Size(0, large ? 48 : NithyaSize.control)),
      padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: large ? NithyaSpace.xl : NithyaSpace.lg)),
      textStyle: WidgetStatePropertyAll(NithyaType.label.toStyle()),
      side: WidgetStatePropertyAll(BorderSide(color: border)),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(pill ? NithyaRadius.pill : NithyaRadius.md)),
      ),
      elevation: const WidgetStatePropertyAll(0),
    );
    final child = icon == null
        ? Text(label)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: NithyaSpace.sm),
              Text(label),
            ],
          );
    final button = FilledButton(onPressed: onPressed, style: style, child: child);
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Square icon-only button. [label] is required: it becomes the tooltip and the
/// accessible name, so no icon button ships unnamed.
class NithyaIconButton extends StatelessWidget {
  const NithyaIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.selected = false,
    this.filled = false,
    this.size = NithyaSize.control,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  /// Selected: controls fill plus a primary ring (mode switchers, active tools).
  final bool selected;

  /// Filled: controls fill without the ring (standalone bar buttons).
  final bool filled;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = NithyaPalette.of(context);
    return IconButton(
      onPressed: onPressed,
      tooltip: label,
      isSelected: selected,
      icon: Icon(icon, size: size * 0.55),
      style: ButtonStyle(
        fixedSize: WidgetStatePropertyAll(Size.square(size)),
        minimumSize: WidgetStatePropertyAll(Size.square(size)),
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.disabled) ? p.muted.withValues(alpha: 0.5) : p.foreground,
        ),
        backgroundColor: WidgetStateProperty.resolveWith((s) {
          final hovered = s.contains(WidgetState.hovered);
          if (selected || filled) return hovered ? Color.lerp(p.controls, p.foreground, 0.08) : p.controls;
          return hovered ? p.controls.withValues(alpha: 0.6) : Colors.transparent;
        }),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        side: WidgetStatePropertyAll(
          selected
              ? const BorderSide(color: NithyaAccent.primary, width: 1.5)
              : BorderSide(color: filled ? p.controlsBorder : Colors.transparent),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(selected ? NithyaRadius.pill : NithyaRadius.md)),
        ),
      ),
    );
  }
}

/// Compact rounded control with icon and label: model pickers, aspect ratio,
/// "Costs", "Help". [selected] outlines it in primary.
class NithyaChip extends StatelessWidget {
  const NithyaChip({super.key, required this.label, this.icon, this.onPressed, this.selected = false});

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final p = NithyaPalette.of(context);
    return TextButton(
      onPressed: onPressed,
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(0, 32)),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: NithyaSpace.md)),
        foregroundColor: WidgetStatePropertyAll(p.foreground),
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.hovered) ? Color.lerp(p.controls, p.foreground, 0.08) : p.controls,
        ),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        textStyle: WidgetStatePropertyAll(NithyaType.label.toStyle()),
        side: WidgetStatePropertyAll(BorderSide(color: selected ? NithyaAccent.primary : p.controlsBorder)),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(NithyaRadius.md))),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 16), const SizedBox(width: NithyaSpace.sm)],
          Text(label),
        ],
      ),
    );
  }
}
