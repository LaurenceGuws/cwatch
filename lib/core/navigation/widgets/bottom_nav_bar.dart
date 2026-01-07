import 'package:flutter/material.dart';

import '../shell_module.dart';
import 'navigation_button.dart';

class BottomNavBar extends StatelessWidget {
  const BottomNavBar({
    required this.modules,
    required this.selected,
    required this.onSelect,
    this.onShowOptions,
    super.key,
  });

  final List<ShellModuleView> modules;
  final String selected;
  final ValueChanged<String> onSelect;
  final ValueChanged<Offset>? onShowOptions;

  static const double height = 72;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onLongPressStart: (details) =>
          onShowOptions?.call(details.globalPosition),
      onSecondaryTapDown: (details) =>
          onShowOptions?.call(details.globalPosition),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.18),
          border: Border(
            top: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
        ),
        child: Row(
          children: modules
              .map(
                (module) => Expanded(
                  child: NavigationButton(
                    destinationId: module.id,
                    icon: module.icon,
                    label: module.label,
                    selected: selected == module.id,
                    onSelect: onSelect,
                    vertical: false,
                    verticalWidth: double.infinity,
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}
