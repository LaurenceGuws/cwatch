import 'package:flutter/material.dart';

import '../../../shared/theme/app_theme.dart';
import '../../../shared/theme/nerd_fonts.dart';

class NavigationButton extends StatefulWidget {
  const NavigationButton({
    required this.destinationId,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onSelect,
    required this.vertical,
    required this.verticalWidth,
    super.key,
  });

  final String destinationId;
  final NerdIcon icon;
  final String label;
  final bool selected;
  final ValueChanged<String> onSelect;
  final bool vertical;
  final double verticalWidth;

  @override
  State<NavigationButton> createState() => _NavigationButtonState();
}

class _NavigationButtonState extends State<NavigationButton> {
  bool _hovering = false;

  void _setHovering(bool hovering) {
    if (_hovering == hovering) return;
    setState(() => _hovering = hovering);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final spacing = context.appTheme.spacing;
    final defaultColor = colorScheme.onSurfaceVariant;
    final hoverColor = colorScheme.primary.withValues(alpha: 0.75);
    final iconColor = widget.selected
        ? colorScheme.primary
        : (_hovering ? hoverColor : defaultColor);
    final indicatorColor = widget.selected
        ? colorScheme.primary
        : Colors.transparent;

    final iconWidget = Icon(widget.icon.data, size: 30, color: iconColor);
    final iconPadding = widget.vertical
        ? const EdgeInsets.only(right: 4)
        : EdgeInsets.zero;

    final buttonWidth = widget.vertical
        ? widget.verticalWidth
        : double.infinity;
    final button = InkWell(
      onTap: () => widget.onSelect(widget.destinationId),
      splashColor: Colors.transparent,
      hoverColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: SizedBox(
        width: buttonWidth,
        height: 56,
        child: widget.vertical
            ? Row(
                children: [
                  Container(width: 4, height: 56, color: indicatorColor),
                  Expanded(
                    child: Center(
                      child: Padding(padding: iconPadding, child: iconWidget),
                    ),
                  ),
                ],
              )
            : Column(
                children: [
                  Container(
                    width: double.infinity,
                    height: 4,
                    color: indicatorColor,
                  ),
                  const Spacer(),
                  iconWidget,
                  const Spacer(),
                ],
              ),
      ),
    );

    return Padding(
      padding: EdgeInsets.symmetric(vertical: spacing.sm),
      child: MouseRegion(
        onEnter: (_) => _setHovering(true),
        onExit: (_) => _setHovering(false),
        cursor: SystemMouseCursors.click,
        child: Tooltip(message: widget.label, child: button),
      ),
    );
  }
}
