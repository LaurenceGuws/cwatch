import 'package:flutter/material.dart';

import 'package:cwatch/model/shared/theme/app_theme.dart';
import '../shell_module.dart';
import 'navigation_button.dart';

class Sidebar extends StatelessWidget {
  static const double width = 48;

  const Sidebar({
    required this.primaryModules,
    required this.secondaryModules,
    required this.selected,
    required this.onSelect,
    this.onShowOptions,
    this.alignRight = false,
    super.key,
  });

  final List<ShellModuleView> primaryModules;
  final List<ShellModuleView> secondaryModules;
  final String selected;
  final ValueChanged<String> onSelect;
  final bool alignRight;
  final ValueChanged<Offset>? onShowOptions;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final spacing = context.appTheme.spacing;
    final decoration = BoxDecoration(
      color: context.appTheme.section.toolbarBackground,
      border: alignRight
          ? Border(
              left: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.4),
              ),
            )
          : Border(
              right: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
    );
    final content = Container(
      width: width,
      margin: alignRight
          ? EdgeInsets.only(left: spacing.xs)
          : EdgeInsets.only(right: spacing.xs),
      decoration: decoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(height: spacing.lg),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: primaryModules
                .map(
                  (module) => NavigationButton(
                    destinationId: module.id,
                    icon: module.icon,
                    label: module.label,
                    selected: selected == module.id,
                    onSelect: onSelect,
                    vertical: true,
                    verticalWidth: width,
                  ),
                )
                .toList(),
          ),
          const Spacer(),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: secondaryModules
                .map(
                  (module) => NavigationButton(
                    destinationId: module.id,
                    icon: module.icon,
                    label: module.label,
                    selected: selected == module.id,
                    onSelect: onSelect,
                    vertical: true,
                    verticalWidth: width,
                  ),
                )
                .toList(),
          ),
          SizedBox(height: spacing.lg),
        ],
      ),
    );
    return GestureDetector(
      onLongPressStart: (details) =>
          onShowOptions?.call(details.globalPosition),
      onSecondaryTapDown: (details) =>
          onShowOptions?.call(details.globalPosition),
      child: content,
    );
  }
}
