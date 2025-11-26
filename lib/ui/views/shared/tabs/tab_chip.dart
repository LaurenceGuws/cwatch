import 'package:flutter/material.dart';

import '../../../../models/ssh_host.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/nerd_fonts.dart';

class TabChipOption {
  const TabChipOption({
    required this.label,
    required this.onSelected,
    this.icon,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onSelected;
  final IconData? icon;
  final bool enabled;
}

class TabCloseWarning {
  const TabCloseWarning({
    required this.title,
    required this.message,
    this.confirmLabel = 'Close tab',
    this.cancelLabel = 'Cancel',
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
}

class TabChip extends StatelessWidget {
  const TabChip({
    super.key,
    required this.host,
    required this.label,
    required this.title,
    required this.icon,
    required this.selected,
    required this.onSelect,
    required this.onClose,
    this.onRename,
    this.options = const [],
    this.closeWarning,
    this.closable = true,
    this.dragIndex,
  });

  final SshHost host;
  final String label;
  final String title;
  final IconData icon;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onClose;
  final VoidCallback? onRename;
  final List<TabChipOption> options;
  final TabCloseWarning? closeWarning;
  final bool closable;
  final int? dragIndex;

  @override
  Widget build(BuildContext context) {
    final appTheme = context.appTheme;
    final chipStyle = appTheme.tabChip.style(
      selected: selected,
      spacing: appTheme.spacing,
    );
    final foreground = chipStyle.foreground;
    final spacing = appTheme.spacing;
    final menuOptions = _buildMenuOptions();
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: spacing.sm * 0.5,
        vertical: spacing.base * 0.75,
      ),
      padding: chipStyle.padding,
      decoration: BoxDecoration(
        color: chipStyle.background,
        borderRadius: chipStyle.borderRadius,
        border: Border.all(color: chipStyle.borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Tooltip(
            message: dragIndex != null ? 'Drag to reorder' : 'Drag handle',
            child: dragIndex != null
                ? ReorderableDragStartListener(
                    index: dragIndex!,
                    child: Icon(NerdIcon.drag.data, size: 16),
                  )
                : Icon(
                    NerdIcon.drag.data,
                    size: 16,
                    color: foreground.withOpacity(0.4),
                  ),
          ),
          Flexible(
            child: InkWell(
              onTap: onSelect,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18, color: foreground),
                  SizedBox(width: spacing.sm),
                  Flexible(
                    child: Text(
                      title,
                      style: appTheme.typography.tabLabel.copyWith(
                        color: foreground,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: spacing.sm),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildOptionsButton(foreground, menuOptions),
              SizedBox(width: spacing.xs),
              IconButton(
                icon: Icon(NerdIcon.close.data, size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: closable ? 'Close tab' : 'Cannot close tab',
                visualDensity: VisualDensity.compact,
                splashRadius: 16,
                onPressed: closable ? () => _handleClose(context) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<TabChipOption> _buildMenuOptions() {
    return [
      TabChipOption(
        label: 'Rename tab',
        icon: NerdIcon.pencil.data,
        enabled: onRename != null,
        onSelected: onRename ?? () {},
      ),
      ...options,
    ];
  }

  Widget _buildOptionsButton(
    Color foreground,
    List<TabChipOption> menuOptions,
  ) {
    return PopupMenuButton<int>(
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      tooltip: 'Tab options',
      iconSize: 16,
      child: SizedBox(
        width: 24,
        height: 24,
        child: Center(
          child: Icon(Icons.more_vert, size: 16, color: foreground),
        ),
      ),
      onSelected: (value) => menuOptions[value].onSelected(),
      itemBuilder: (context) {
        return List.generate(menuOptions.length, (index) {
          final option = menuOptions[index];
          return PopupMenuItem<int>(
            value: index,
            enabled: option.enabled,
            child: Row(
              children: [
                if (option.icon != null) ...[
                  Icon(option.icon, size: 18),
                  const SizedBox(width: 8),
                ],
                Text(option.label),
              ],
            ),
          );
        });
      },
    );
  }

  Future<void> _handleClose(BuildContext context) async {
    final shouldClose =
        closeWarning == null || await _showCloseWarning(context);
    if (!shouldClose) {
      return;
    }
    onClose();
  }

  Future<bool> _showCloseWarning(BuildContext context) async {
    final warning = closeWarning!;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(warning.title),
          content: Text(warning.message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(warning.cancelLabel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(warning.confirmLabel),
            ),
          ],
        );
      },
    );
    return result == true;
  }
}
