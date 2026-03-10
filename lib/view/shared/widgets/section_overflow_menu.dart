import 'package:flutter/material.dart';

import 'package:cwatch/model/shared/theme/app_theme.dart';

class SectionMenuAction<T> {
  const SectionMenuAction({
    required this.value,
    required this.label,
    this.enabled = true,
  });

  final T value;
  final String label;
  final bool enabled;
}

class SectionOverflowMenu<T> extends StatelessWidget {
  const SectionOverflowMenu({
    super.key,
    required this.actions,
    required this.onSelected,
    this.tooltip = 'Section options',
    this.icon = Icons.more_horiz,
    this.iconSize,
  });

  final List<SectionMenuAction<T>> actions;
  final ValueChanged<T> onSelected;
  final String tooltip;
  final IconData icon;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      tooltip: tooltip,
      icon: Icon(icon, size: iconSize ?? context.appTheme.iconSizes.medium),
      onSelected: onSelected,
      itemBuilder: (context) => actions
          .map(
            (action) => PopupMenuItem<T>(
              value: action.value,
              enabled: action.enabled,
              child: Text(action.label),
            ),
          )
          .toList(),
    );
  }
}
