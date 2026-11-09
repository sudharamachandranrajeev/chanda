import 'package:flutter/material.dart';

import '../palette.dart';
import '../tokens.g.dart';
import 'buttons.dart';

/// Shows [builder] over a scrim tinted by the theme. Escape and a scrim tap close it.
Future<T?> showNithyaDialog<T>(BuildContext context, {required WidgetBuilder builder}) {
  final p = NithyaPalette.of(context);
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: p.scrim.withValues(alpha: p.scrimAlpha),
    transitionDuration: NithyaMotion.base,
    pageBuilder: (context, _, _) => SafeArea(child: Center(child: builder(context))),
    transitionBuilder: (context, anim, _, child) => FadeTransition(
      opacity: anim,
      child: ScaleTransition(scale: Tween(begin: 0.97, end: 1.0).animate(anim), child: child),
    ),
  );
}

/// Dialog card: title row with a close button, [child], then right-aligned [actions].
class NithyaDialog extends StatelessWidget {
  const NithyaDialog({super.key, required this.title, required this.child, this.actions = const [], this.width = 520});

  final String title;
  final Widget child;
  final List<Widget> actions;
  final double width;

  @override
  Widget build(BuildContext context) {
    final p = NithyaPalette.of(context);
    return _DialogCard(
      width: width,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(NithyaSpace.xl, NithyaSpace.lg, NithyaSpace.lg, NithyaSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(title, style: NithyaType.title.toStyle(color: p.foreground).copyWith(fontSize: 20)),
                  ),
                ),
                NithyaIconButton(
                  icon: Icons.close_rounded,
                  label: 'Close',
                  filled: true,
                  size: 32,
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
            const SizedBox(height: NithyaSpace.lg),
            Flexible(child: SingleChildScrollView(child: child)),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: NithyaSpace.xl),
              Row(mainAxisAlignment: MainAxisAlignment.end, spacing: NithyaSpace.sm, children: actions),
            ],
          ],
        ),
      ),
    );
  }
}

/// One page of a [NithyaSectionedDialog].
@immutable
class NithyaSection {
  const NithyaSection({required this.icon, required this.label, required this.builder});

  final IconData icon;
  final String label;
  final WidgetBuilder builder;
}

/// Two-pane dialog with a section list on the left: settings, preferences.
class NithyaSectionedDialog extends StatefulWidget {
  const NithyaSectionedDialog({super.key, required this.title, required this.sections, this.initial = 0});

  final String title;
  final List<NithyaSection> sections;
  final int initial;

  @override
  State<NithyaSectionedDialog> createState() => _NithyaSectionedDialogState();
}

class _NithyaSectionedDialogState extends State<NithyaSectionedDialog> {
  late int _index = widget.initial;

  @override
  Widget build(BuildContext context) {
    final p = NithyaPalette.of(context);
    final section = widget.sections[_index];
    return _DialogCard(
      width: 780,
      height: 560,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: NithyaSize.sideNav,
            child: Padding(
              padding: const EdgeInsets.all(NithyaSpace.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(NithyaSpace.xs, NithyaSpace.xs, 0, NithyaSpace.md),
                    child: Text(
                      widget.title,
                      style: NithyaType.heading.toStyle(color: p.foreground).copyWith(fontSize: 19),
                    ),
                  ),
                  for (final (i, s) in widget.sections.indexed)
                    _NavItem(section: s, selected: i == _index, onTap: () => setState(() => _index = i)),
                ],
              ),
            ),
          ),
          VerticalDivider(width: 1, color: p.divider),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(NithyaSpace.lg, NithyaSpace.md, NithyaSpace.md, NithyaSpace.md),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          section.label,
                          style: NithyaType.heading.toStyle(color: p.foreground).copyWith(fontSize: 19),
                        ),
                      ),
                      NithyaIconButton(
                        icon: Icons.close_rounded,
                        label: 'Close',
                        filled: true,
                        size: 32,
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(NithyaSpace.lg),
                    child: Builder(builder: section.builder),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.section, required this.selected, required this.onTap});

  final NithyaSection section;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = NithyaPalette.of(context);
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(NithyaRadius.md),
        hoverColor: p.controls.withValues(alpha: 0.5),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: NithyaSpace.md, vertical: NithyaSpace.sm + 2),
          margin: const EdgeInsets.only(bottom: NithyaSpace.xxs),
          decoration: BoxDecoration(
            color: selected ? p.controls : Colors.transparent,
            borderRadius: BorderRadius.circular(NithyaRadius.md),
          ),
          child: Row(
            children: [
              Icon(section.icon, size: 20, color: p.foreground),
              const SizedBox(width: NithyaSpace.md),
              Text(section.label, style: NithyaType.body.toStyle(color: p.foreground)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DialogCard extends StatelessWidget {
  const _DialogCard({required this.child, required this.width, this.height});

  final Widget child;
  final double width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final p = NithyaPalette.of(context);
    return Material(
      type: MaterialType.transparency,
      child: Container(
        width: width,
        height: height,
        margin: const EdgeInsets.all(NithyaSpace.lg),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: p.modal,
          borderRadius: BorderRadius.circular(NithyaRadius.xl),
          border: Border.all(color: p.panelBorder),
          boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 48, offset: Offset(0, 16))],
        ),
        child: child,
      ),
    );
  }
}

/// Settings row: bold title, muted explanation, switch underneath.
class NithyaSwitchRow extends StatelessWidget {
  const NithyaSwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.description,
  });

  final String title;
  final String? description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = NithyaPalette.of(context);
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.only(bottom: NithyaSpace.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: NithyaType.heading.toStyle(color: p.foreground).copyWith(fontSize: 15)),
            if (description != null) ...[
              const SizedBox(height: NithyaSpace.xs),
              Text(description!, style: NithyaType.caption.toStyle(color: p.muted)),
            ],
            const SizedBox(height: NithyaSpace.sm),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}
