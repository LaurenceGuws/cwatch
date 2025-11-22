import 'package:flutter/material.dart';

import '../../../../models/ssh_host.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/nerd_fonts.dart';

class ServerTabChip extends StatelessWidget {
  const ServerTabChip({
    super.key,
    required this.host,
    required this.label,
    required this.title,
    required this.icon,
    required this.selected,
    required this.onSelect,
    required this.onClose,
    this.onRename,
    this.showActions = true,
    this.showClose = true,
    required this.dragIndex,
  });

  final SshHost host;
  final String label;
  final String title;
  final IconData icon;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onClose;
  final VoidCallback? onRename;
  final bool showActions;
  final bool showClose;
  final int dragIndex;

  @override
  Widget build(BuildContext context) {
    final appTheme = context.appTheme;
    final chipStyle = appTheme.tabChip.style(selected: selected, spacing: appTheme.spacing);
    final foreground = chipStyle.foreground;
    final spacing = appTheme.spacing;
    return Container(
      margin: EdgeInsets.symmetric(horizontal: spacing.sm * 0.5, vertical: spacing.base * 0.75),
      padding: chipStyle.padding,
      decoration: BoxDecoration(
        color: chipStyle.background,
        borderRadius: chipStyle.borderRadius,
        border: Border.all(color: chipStyle.borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: onSelect,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: foreground),
                SizedBox(width: spacing.sm * 0.75),
                Text(
                  title,
                  style: appTheme.typography.tabLabel.copyWith(
                    color: foreground,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (showActions && onRename != null)
            IconButton(
              icon: Icon(NerdIcon.pencil.data, size: 16, color: foreground),
              visualDensity: VisualDensity.compact,
              splashRadius: 16,
              tooltip: 'Rename tab',
              onPressed: onRename,
            ),
          if (showActions && showClose)
            IconButton(
              icon: Icon(NerdIcon.close.data, size: 16, color: foreground),
              visualDensity: VisualDensity.compact,
              splashRadius: 16,
              tooltip: 'Close tab',
              onPressed: onClose,
            ),
          if (showActions && dragIndex >= 0)
            ReorderableDragStartListener(
              index: dragIndex,
              child: Icon(NerdIcon.drag.data, size: 16),
            ),
        ],
      ),
    );
  }
}
