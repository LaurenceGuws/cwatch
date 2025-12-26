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
    this.horizontalPadding,
    this.stripeIndex,
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
  final double? horizontalPadding;
  final int? stripeIndex;

  @override
  State<SelectableListItem> createState() => _SelectableListItemState();
}

class _SelectableListItemState extends State<SelectableListItem> {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final spacing = context.appTheme.spacing;
    final listTokens = context.appTheme.list;
    final stripeBackground = widget.stripeIndex == null
        ? Colors.transparent
        : (widget.stripeIndex!.isEven
            ? listTokens.stripeEvenBackground
            : listTokens.stripeOddBackground);
    final background =
        widget.selected ? listTokens.selectedBackground : stripeBackground;
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
      borderRadius: BorderRadius.zero,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.onTapDown,
        onDoubleTapDown: widget.onDoubleTapDown,
        onSecondaryTapDown: widget.onSecondaryTapDown,
        child: InkWell(
          onTap: widget.onTap,
          onDoubleTap: widget.onDoubleTap,
          onLongPress: widget.onLongPress,
          borderRadius: BorderRadius.zero,
          overlayColor: overlay,
          enableFeedback: false,
          splashFactory: NoSplash.splashFactory,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: widget.horizontalPadding ?? spacing.sm,
              vertical: spacing.sm,
            ),
            decoration: const BoxDecoration(borderRadius: BorderRadius.zero),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (widget.leading != null) ...[
                  widget.leading!,
                  SizedBox(width: spacing.lg),
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
                                        ? FontWeight.bold
                                        : FontWeight.normal,
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
                  SizedBox(width: spacing.md),
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
                  SizedBox(width: spacing.md),
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
