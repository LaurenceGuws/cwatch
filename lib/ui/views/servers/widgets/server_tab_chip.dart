import 'package:flutter/material.dart';

import '../../../../models/ssh_host.dart';

class ServerTabChip extends StatelessWidget {
  const ServerTabChip({
    super.key,
    required this.host,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onSelect,
    required this.onClose,
  });

  final SshHost host;
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final background = selected ? colorScheme.primaryContainer : Colors.transparent;
    final foreground = selected ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: selected ? colorScheme.primary : colorScheme.outlineVariant),
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
                const SizedBox(width: 6),
                Text(
                  '${host.name} • $label',
                  style: TextStyle(
                    color: foreground,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 16, color: foreground),
            visualDensity: VisualDensity.compact,
            splashRadius: 16,
            tooltip: 'Close tab',
            onPressed: onClose,
          ),
          const Icon(Icons.drag_indicator, size: 16),
        ],
      ),
    );
  }
}
