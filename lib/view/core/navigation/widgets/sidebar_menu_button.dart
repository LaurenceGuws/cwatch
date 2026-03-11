import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../window_controls_constants.dart';
import 'package:cwatch/model/shared/theme/app_theme.dart';

class SidebarMenuButton extends StatefulWidget {
  const SidebarMenuButton({
    required this.collapsed,
    required this.onShowOptions,
    super.key,
  });

  final bool collapsed;
  final ValueChanged<Offset> onShowOptions;

  @override
  State<SidebarMenuButton> createState() => _SidebarMenuButtonState();
}

class _SidebarMenuButtonState extends State<SidebarMenuButton> {
  Offset? _tapPosition;
  bool _hovering = false;

  void _onTapDown(TapDownDetails details) {
    _tapPosition = details.globalPosition;
  }

  void _onTap() {
    final position = _tapPosition ?? Offset.zero;
    widget.onShowOptions(position);
  }

  void _setHovering(bool value) {
    if (_hovering == value) return;
    setState(() => _hovering = value);
  }

  @override
  Widget build(BuildContext context) {
    final tooltip = widget.collapsed ? 'Show navigation' : 'Sidebar options';

    // Match the tab bar height when custom chrome is enabled
    final bool useCustomChrome =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.linux);
    final buttonSize = useCustomChrome
        ? WindowControlsConstants.tabBarHeightFor(context)
        : context.scale(48.0);

    final colorScheme = Theme.of(context).colorScheme;
    final listTokens = context.appTheme.list;
    final hoverColor = listTokens.hoverBackground;
    final borderColor = _hovering ? listTokens.hoverBorder : Colors.transparent;

    return MouseRegion(
      onEnter: (_) => _setHovering(true),
      onExit: (_) => _setHovering(false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTap: _onTap,
        behavior: HitTestBehavior.translucent,
        child: Tooltip(
          message: tooltip,
          child: Container(
            width: buttonSize,
            height: buttonSize,
            decoration: BoxDecoration(
              color: _hovering ? hoverColor : Colors.transparent,
              border: Border.all(color: borderColor),
            ),
            child: Icon(
              widget.collapsed ? Icons.menu : Icons.menu_open,
              size: context.appTheme.iconSizes.medium,
              color: colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
