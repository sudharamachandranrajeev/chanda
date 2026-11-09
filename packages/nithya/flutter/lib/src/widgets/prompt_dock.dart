import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../palette.dart';
import '../tokens.g.dart';
import 'surfaces.dart';

/// Bottom-docked prompt composer: an optional [leading] slot (references), a
/// multi-line field, a row of [options] chips and the send button.
///
/// With [enterToSubmit] on, Enter sends and Shift+Enter adds a newline; with it
/// off, both add a newline and only the button sends.
class NithyaPromptDock extends StatefulWidget {
  const NithyaPromptDock({
    super.key,
    required this.onSubmit,
    this.controller,
    this.hint = 'Describe what you want…',
    this.leading,
    this.options = const [],
    this.trailing = const [],
    this.enterToSubmit = false,
    this.maxWidth = NithyaSize.promptDock,
  });

  final ValueChanged<String> onSubmit;
  final TextEditingController? controller;
  final String hint;
  final Widget? leading;
  final List<Widget> options;
  final List<Widget> trailing;
  final bool enterToSubmit;
  final double maxWidth;

  @override
  State<NithyaPromptDock> createState() => _NithyaPromptDockState();
}

class _NithyaPromptDockState extends State<NithyaPromptDock> {
  late final TextEditingController _own = TextEditingController();
  late final FocusNode _focus = FocusNode(onKeyEvent: _onKey);

  TextEditingController get _text => widget.controller ?? _own;

  @override
  void dispose() {
    _own.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _text.text.trim();
    if (value.isEmpty) return;
    widget.onSubmit(value);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (!widget.enterToSubmit || e is! KeyDownEvent) return KeyEventResult.ignored;
    if (e.logicalKey != LogicalKeyboardKey.enter && e.logicalKey != LogicalKeyboardKey.numpadEnter) {
      return KeyEventResult.ignored;
    }
    if (HardwareKeyboard.instance.isShiftPressed) return KeyEventResult.ignored;
    _submit();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final p = NithyaPalette.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: widget.maxWidth),
      child: NithyaPanel(
        padding: const EdgeInsets.all(NithyaSpace.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.leading != null) ...[widget.leading!, const SizedBox(width: NithyaSpace.md)],
                Expanded(
                  child: TextField(
                    controller: _text,
                    focusNode: _focus,
                    minLines: 2,
                    maxLines: 6,
                    keyboardType: TextInputType.multiline,
                    style: NithyaType.body.toStyle(color: p.foreground).copyWith(fontSize: 15),
                    decoration: InputDecoration(
                      hintText: widget.hint,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: NithyaSpace.sm),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: NithyaSpace.sm),
            Row(
              children: [
                Expanded(
                  child: Wrap(spacing: NithyaSpace.sm, runSpacing: NithyaSpace.sm, children: widget.options),
                ),
                ...widget.trailing,
                const SizedBox(width: NithyaSpace.sm),
                ListenableBuilder(
                  listenable: _text,
                  builder: (context, _) {
                    final ready = _text.text.trim().isNotEmpty;
                    return IconButton.filled(
                      tooltip: 'Generate',
                      onPressed: ready ? _submit : null,
                      icon: const Icon(Icons.arrow_upward_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: NithyaAccent.primary,
                        foregroundColor: NithyaAccent.onPrimary,
                        disabledBackgroundColor: NithyaAccent.primary.withValues(alpha: 0.35),
                        disabledForegroundColor: NithyaAccent.onPrimary.withValues(alpha: 0.6),
                        fixedSize: const Size.square(NithyaSize.control),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Dashed square slot for adding a reference image to a prompt.
class NithyaReferenceSlot extends StatelessWidget {
  const NithyaReferenceSlot({super.key, required this.onPressed, this.label = 'Reference'});

  final VoidCallback? onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = NithyaPalette.of(context);
    return Tooltip(
      message: 'Add $label',
      child: Semantics(
        button: true,
        label: 'Add $label',
        child: GestureDetector(
          onTap: onPressed,
          child: NithyaDashedBox(
            radius: NithyaRadius.md,
            child: SizedBox.square(
              dimension: 56,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_rounded, color: p.foreground, size: 20),
                  Text(label, style: NithyaType.caption.toStyle(color: p.muted).copyWith(fontSize: 9)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
