import 'package:flutter/material.dart';

import 'package:cwatch/models/ssh_host.dart';
import '../../theme/app_theme.dart';
import '../../theme/nerd_fonts.dart';
import '../servers/widgets/server_tab_chip.dart';
import 'engine_tab.dart';

class EngineWorkspace extends StatelessWidget {
  const EngineWorkspace({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onSelect,
    required this.onClose,
    required this.onReorder,
    this.leading,
    this.onAddTab,
  });

  final List<EngineTab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final ValueChanged<int> onClose;
  final void Function(int oldIndex, int newIndex) onReorder;
  final Widget? leading;
  final VoidCallback? onAddTab;

  @override
  Widget build(BuildContext context) {
    final appTheme = context.appTheme;
    final safeIndex = tabs.isEmpty ? 0 : selectedIndex.clamp(0, tabs.length - 1);
    return Column(
      children: [
        Material(
          color: appTheme.section.toolbarBackground,
          child: Row(
            children: [
              if (leading != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: SizedBox(
                    height: 48,
                    child: Center(child: leading),
                  ),
                ),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ReorderableListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    buildDefaultDragHandles: false,
                    onReorder: onReorder,
                    itemCount: tabs.length,
                    itemBuilder: (context, index) {
                      final tab = tabs[index];
                      return ServerTabChip(
                        key: ValueKey(tab.id),
                        host: SshHost(
                          name: tab.label,
                          hostname: '',
                          port: 0,
                          available: true,
                        ),
                        title: tab.title,
                        label: tab.label,
                        icon: tab.icon,
                        selected: index == safeIndex,
                        onSelect: () => onSelect(index),
                        onClose:
                            tabs.length <= 1 ? () {} : () => onClose(index),
                        onRename: tab.canRename ? () {} : null,
                        showActions: true,
                        showClose: tabs.length > 1,
                        dragIndex: tab.canDrag ? index : -1,
                      );
                    },
                  ),
                ),
              ),
              IconButton(
                tooltip: 'New tab',
                icon: Icon(NerdIcon.add.data),
                onPressed: onAddTab,
              ),
            ],
          ),
        ),
        Divider(height: 1, color: appTheme.section.divider),
        Expanded(
          child: IndexedStack(
            index: safeIndex,
            children: tabs.isEmpty
                ? [const SizedBox.shrink()]
                : tabs
                    .asMap()
                    .entries
                    .map(
                      (entry) => KeyedSubtree(
                        key: ValueKey('engine-tab-${entry.value.id}'),
                        child: entry.value.body,
                      ),
                    )
                    .toList(),
          ),
        ),
      ],
    );
  }
}
