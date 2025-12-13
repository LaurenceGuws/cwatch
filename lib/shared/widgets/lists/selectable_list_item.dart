import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Styled list item that surfaces hover/focus/selection consistently.
class SelectableListItem extends StatefulWidget {
  const SelectableListItem({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.badge,
    this.trailing,
    this.selected = false,
    this.focused = false,
    this.busy = false,
    this.onTap,
    this.onTapDown,
    this.onDoubleTapDown,
    this.onDoubleTap,
    this.onLongPress,
    this.onSecondaryTapDown,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? badge;
  final Widget? trailing;
  final bool selected;
  final bool focused;
  final bool busy;
  final VoidCallback? onTap;
  final void Function(TapDownDetails details)? onTapDown;
  final void Function(TapDownDetails details)? onDoubleTapDown;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongPress;
  final void Function(TapDownDetails details)? onSecondaryTapDown;

  @override
  State<SelectableListItem> createState() => _SelectableListItemState();
}

class _SelectableListItemState extends State<SelectableListItem> {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final spacing = context.appTheme.spacing;
    final listTokens = context.appTheme.list;
    final background = widget.selected
        ? listTokens.selectedBackground
        : Colors.transparent;
    final foreground = widget.selected
        ? listTokens.selectedForeground
        : listTokens.unselectedForeground;

    final overlay = WidgetStateProperty.resolveWith<Color?>((states) {
      if (states.contains(WidgetState.hovered) ||
          states.contains(WidgetState.pressed)) {
        return listTokens.hoverBackground;
      }
      return null;
    });

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(8),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.onTapDown,
        onDoubleTapDown: widget.onDoubleTapDown,
        onSecondaryTapDown: widget.onSecondaryTapDown,
        child: InkWell(
          onTap: widget.onTap,
          onDoubleTap: widget.onDoubleTap,
          onLongPress: widget.onLongPress,
          borderRadius: BorderRadius.circular(8),
          overlayColor: overlay,
          enableFeedback: false,
          splashFactory: NoSplash.splashFactory,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: spacing.base * 2,
              vertical: spacing.base * 1.2,
            ),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (widget.leading != null) ...[
                  widget.leading!,
                  SizedBox(width: spacing.base * 1.5),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.title,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: foreground,
                                    fontWeight: widget.selected
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                  ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (widget.badge != null) ...[
                            SizedBox(width: spacing.sm),
                            widget.badge!,
                          ],
                        ],
                      ),
                      if (widget.subtitle != null &&
                          widget.subtitle!.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.only(top: spacing.xs),
                          child: Text(
                            widget.subtitle!,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
                if (widget.busy) ...[
                  SizedBox(width: spacing.base),
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(scheme.primary),
                    ),
                  ),
                ],
                if (widget.trailing != null) ...[
                  SizedBox(width: spacing.base),
                  widget.trailing!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
