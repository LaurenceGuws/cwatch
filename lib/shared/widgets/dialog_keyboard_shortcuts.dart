import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DialogKeyboardShortcuts extends StatefulWidget {
  const DialogKeyboardShortcuts({
    super.key,
    required this.child,
    this.onConfirm,
    this.onCancel,
  });

  final Widget child;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;

  @override
  State<DialogKeyboardShortcuts> createState() =>
      _DialogKeyboardShortcutsState();
}

class _DialogKeyboardShortcutsState extends State<DialogKeyboardShortcuts> {
  bool _allowEnter = true;

  @override
  void initState() {
    super.initState();
    _allowEnter = _shouldAllowEnter();
    FocusManager.instance.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_handleFocusChange);
    super.dispose();
  }

  void _handleFocusChange() {
    final next = _shouldAllowEnter();
    if (next != _allowEnter) {
      setState(() => _allowEnter = next);
    }
  }

  bool _shouldAllowEnter() {
    final focused = FocusManager.instance.primaryFocus?.context?.widget;
    if (focused is EditableText) {
      final maxLines = focused.maxLines;
      if (maxLines == null || maxLines > 1) {
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final bindings = <ShortcutActivator, VoidCallback>{};
    if (widget.onCancel != null) {
      bindings[const SingleActivator(LogicalKeyboardKey.escape)] =
          widget.onCancel!;
    }
    if (widget.onConfirm != null && _allowEnter) {
      bindings[const SingleActivator(LogicalKeyboardKey.enter)] =
          widget.onConfirm!;
      bindings[const SingleActivator(LogicalKeyboardKey.numpadEnter)] =
          widget.onConfirm!;
    }

    if (bindings.isEmpty) {
      return widget.child;
    }

    return CallbackShortcuts(bindings: bindings, child: widget.child);
  }
}
