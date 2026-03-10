import 'package:flutter/material.dart';

import 'package:cwatch/controller/core/workspace/tab_options.dart';
import 'package:cwatch/controller/core/workspace/workspace_tab.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/view/shared/views/shared/tabs/tab_chip.dart';

class WorkspaceTabChipBuilder extends StatelessWidget {
  const WorkspaceTabChipBuilder({
    super.key,
    required this.tab,
    required this.selected,
    required this.host,
    required this.onSelect,
    required this.onClose,
    required this.index,
    this.onRename,
    this.extraOptions = const [],
    this.closeWarning,
    this.closable = true,
    this.canRename,
    this.canDrag,
  });

  final WorkspaceTab tab;
  final bool selected;
  final SshHost host;
  final VoidCallback onSelect;
  final VoidCallback onClose;
  final VoidCallback? onRename;
  final int index;
  final List<TabChipOption> extraOptions;
  final TabCloseWarning? closeWarning;
  final bool closable;
  final bool? canRename;
  final bool? canDrag;

  @override
  Widget build(BuildContext context) {
    final optionsController = tab.optionsController;
    if (optionsController == null) {
      return KeyedSubtree(
        key: ValueKey(tab.id),
        child: _buildChip(const []),
      );
    }

    return ValueListenableBuilder<List<TabChipOption>>(
      key: ValueKey(tab.id),
      valueListenable: optionsController,
      builder: (context, options, _) => _buildChip(options),
    );
  }

  Widget _buildChip(List<TabChipOption> options) {
    final effectiveCanRename = canRename ?? tab.canRename;
    final effectiveCanDrag = canDrag ?? tab.canDrag;
    return TabChip(
      host: host,
      title: tab.title,
      label: tab.label,
      icon: tab.icon,
      selected: selected,
      onSelect: onSelect,
      onClose: onClose,
      onRename: effectiveCanRename ? onRename : null,
      dragIndex: effectiveCanDrag ? index : null,
      options: [...options, ...extraOptions],
      closeWarning: closeWarning,
      closable: closable,
    );
  }
}
