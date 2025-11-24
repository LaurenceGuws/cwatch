import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class SectionListItem extends StatelessWidget {
  const SectionListItem({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.badge,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.onDoubleTap,
    this.onSecondaryTapDown,
    this.selected = false,
    this.busy = false,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? badge;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onDoubleTap;
  final void Function(TapDownDetails details)? onSecondaryTapDown;
  final bool selected;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final spacing = context.appTheme.spacing;
    final background = selected
        ? scheme.primary.withValues(alpha: 0.08)
        : Colors.transparent;
    final foreground = selected ? scheme.primary : scheme.onSurface;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTapDown: onSecondaryTapDown,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        onDoubleTap: onDoubleTap,
        child: Container(
          color: background,
          padding: EdgeInsets.symmetric(
            horizontal: spacing.base * 2,
            vertical: spacing.base * 1.2,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (leading != null) ...[
                leading!,
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
                            title,
                            style:
                                Theme.of(context).textTheme.titleMedium?.copyWith(
                                      color: foreground,
                                    ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (badge != null) ...[
                          SizedBox(width: spacing.sm),
                          badge!,
                        ],
                      ],
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: spacing.xs),
                        child: Text(
                          subtitle!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              if (busy) ...[
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
              if (trailing != null) ...[
                SizedBox(width: spacing.base),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
