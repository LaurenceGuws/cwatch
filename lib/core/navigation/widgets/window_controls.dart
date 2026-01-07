import 'package:flutter/material.dart';

import '../../../shared/theme/app_theme.dart';
import '../window_controls_constants.dart';

class WindowControls extends StatefulWidget {
  const WindowControls({
    required this.isMaximized,
    required this.onDrag,
    required this.onToggleMaximize,
    required this.onMinimize,
    required this.onClose,
    super.key,
  });

  static const double height = WindowControlsConstants.height;
  static const double totalWidth = WindowControlsConstants.totalWidth;

  final bool isMaximized;
  final VoidCallback onDrag;
  final VoidCallback onToggleMaximize;
  final VoidCallback onMinimize;
  final VoidCallback onClose;

  @override
  State<WindowControls> createState() => _WindowControlsState();
}

class _WindowControlsState extends State<WindowControls> {
  @override
  Widget build(BuildContext context) {
    final toolbarColor = context.appTheme.section.toolbarBackground;

    return Container(
      color: toolbarColor,
      padding: const EdgeInsets.only(right: 4),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) => widget.onDrag(),
        onDoubleTap: widget.onToggleMaximize,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _CaptionButton(
              icon: Icons.remove_rounded,
              tooltip: 'Minimize',
              onPressed: widget.onMinimize,
            ),
            _CaptionButton(
              icon: widget.isMaximized
                  ? Icons.filter_none_rounded
                  : Icons.check_box_outline_blank_rounded,
              tooltip: widget.isMaximized ? 'Restore' : 'Maximize',
              onPressed: widget.onToggleMaximize,
            ),
            _CaptionButton(
              icon: Icons.close_rounded,
              tooltip: 'Close',
              onPressed: widget.onClose,
              destructive: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _CaptionButton extends StatefulWidget {
  const _CaptionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.destructive = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool destructive;

  @override
  State<_CaptionButton> createState() => _CaptionButtonState();
}

class _CaptionButtonState extends State<_CaptionButton> {
  bool _hovering = false;

  void _setHover(bool hovering) {
    if (_hovering == hovering) return;
    setState(() => _hovering = hovering);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hoverColor = widget.destructive
        ? scheme.error.withValues(alpha: 0.8)
        : scheme.surfaceContainerHighest.withValues(alpha: 0.35);
    final iconColor = widget.destructive
        ? (_hovering ? scheme.onError : scheme.onSurface)
        : scheme.onSurface;
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => _setHover(true),
        onExit: (_) => _setHover(false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: Container(
            width: WindowControlsConstants.buttonWidth,
            height: WindowControlsConstants.height,
            color: _hovering ? hoverColor : Colors.transparent,
            child: Icon(widget.icon, size: 18, color: iconColor),
          ),
        ),
      ),
    );
  }
}
