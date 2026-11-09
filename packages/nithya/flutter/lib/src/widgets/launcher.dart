import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../palette.dart';
import '../tokens.g.dart';

enum NithyaBadgeKind {
  fresh('NEW', NithyaBadgeHues.new_),
  beta('BETA', NithyaBadgeHues.beta),
  soon('SOON', NithyaBadgeHues.soon);

  const NithyaBadgeKind(this.text, this.hue);

  final String text;
  final Color hue;
}

/// Small uppercase status tag.
class NithyaBadge extends StatelessWidget {
  const NithyaBadge(this.kind, {super.key});

  final NithyaBadgeKind kind;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: kind.hue.withValues(alpha: 0.22),
      borderRadius: BorderRadius.circular(NithyaRadius.xs),
    ),
    child: Text(kind.text, style: NithyaType.overline.toStyle(color: kind.hue).copyWith(fontSize: 9.5)),
  );
}

/// Centred headline for launchers and empty tool screens. When [accent] occurs
/// in [title], that word is painted in the primary colour.
class NithyaHero extends StatelessWidget {
  const NithyaHero({super.key, required this.title, this.accent, this.subtitle, this.compact = false});

  final String title;
  final String? accent;
  final String? subtitle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = NithyaPalette.of(context);
    final style = (compact ? NithyaType.title : NithyaType.hero).toStyle(color: p.foreground);
    final at = accent == null ? -1 : title.indexOf(accent!);
    final spans = at < 0
        ? [TextSpan(text: title)]
        : [
            TextSpan(text: title.substring(0, at)),
            TextSpan(
              text: accent,
              style: const TextStyle(color: NithyaAccent.primary),
            ),
            TextSpan(text: title.substring(at + accent!.length)),
          ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text.rich(
          TextSpan(children: spans),
          style: style,
          textAlign: TextAlign.center,
        ),
        if (subtitle != null) ...[
          const SizedBox(height: NithyaSpace.md),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: NithyaType.body.toStyle(color: p.muted).copyWith(fontSize: compact ? 15 : 17),
          ),
        ],
      ],
    );
  }
}

/// Small heading above a group of cards.
class NithyaSectionLabel extends StatelessWidget {
  const NithyaSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: NithyaSpace.md, top: NithyaSpace.xl),
    child: Semantics(
      header: true,
      child: Text(text, style: NithyaType.label.toStyle(color: NithyaPalette.of(context).foreground)),
    ),
  );
}

/// Rounded square tinted with a tool's hue, holding its icon.
class NithyaIconTile extends StatelessWidget {
  const NithyaIconTile({super.key, required this.icon, required this.hue, this.size = NithyaSize.toolTile});

  final IconData icon;
  final Color hue;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: hue.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(size * 0.27),
      border: Border.all(color: hue.withValues(alpha: 0.28)),
    ),
    child: Icon(icon, color: hue, size: size * 0.5),
  );
}

/// Launcher card for one tool. A [NithyaBadgeKind.soon] badge or a null [onTap]
/// disables it.
class NithyaToolCard extends StatefulWidget {
  const NithyaToolCard({
    super.key,
    required this.icon,
    required this.hue,
    required this.title,
    required this.description,
    this.badge,
    this.onTap,
  });

  final IconData icon;
  final Color hue;
  final String title;
  final String description;
  final NithyaBadgeKind? badge;
  final VoidCallback? onTap;

  @override
  State<NithyaToolCard> createState() => _NithyaToolCardState();
}

class _NithyaToolCardState extends State<NithyaToolCard> {
  bool _hover = false;

  bool get _enabled => widget.onTap != null && widget.badge != NithyaBadgeKind.soon;

  @override
  Widget build(BuildContext context) {
    final p = NithyaPalette.of(context);
    final card = AnimatedContainer(
      duration: NithyaMotion.fast,
      padding: const EdgeInsets.all(NithyaSpace.xl - 4),
      decoration: BoxDecoration(
        color: p.controls.withValues(alpha: _hover && _enabled ? 0.9 : 0.5),
        borderRadius: BorderRadius.circular(NithyaRadius.xl),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NithyaIconTile(icon: widget.icon, hue: widget.hue),
          const SizedBox(width: NithyaSpace.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: NithyaSpace.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(widget.title, style: NithyaType.heading.toStyle(color: p.foreground)),
                    if (widget.badge != null) NithyaBadge(widget.badge!),
                  ],
                ),
                const SizedBox(height: NithyaSpace.xs),
                Text(widget.description, style: NithyaType.body.toStyle(color: p.muted)),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_rounded, size: 20, color: p.muted),
        ],
      ),
    );
    return Semantics(
      button: true,
      enabled: _enabled,
      label: '${widget.title}. ${widget.description}',
      excludeSemantics: true,
      child: MouseRegion(
        cursor: _enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: _enabled ? widget.onTap : null,
          child: Opacity(opacity: _enabled ? 1 : 0.55, child: card),
        ),
      ),
    );
  }
}

/// Lays cards out in equal columns, up to [maxColumns], each at least
/// [minTileWidth] wide.
class NithyaToolGrid extends StatelessWidget {
  const NithyaToolGrid({super.key, required this.children, this.maxColumns = 3, this.minTileWidth = 300});

  final List<Widget> children;
  final int maxColumns;
  final double minTileWidth;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      const gap = NithyaSpace.md;
      final cols = math.max(1, math.min(maxColumns, ((c.maxWidth + gap) / (minTileWidth + gap)).floor()));
      final width = (c.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [for (final child in children) SizedBox(width: width, child: child)],
      );
    },
  );
}
