import 'package:flutter/material.dart';

import 'package:cwatch/models/ssh_host.dart';
import '../../theme/app_theme.dart';
import '../../theme/nerd_fonts.dart';
import 'tabs/tab_chip.dart';
import 'engine_tab.dart';

class DockerEngineList extends StatelessWidget {
  const DockerEngineList({
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
    final safeIndex = tabs.isEmpty
        ? 0
        : selectedIndex.clamp(0, tabs.length - 1);
    return Column(
      children: [
        Material(
          color: appTheme.section.toolbarBackground,
          child: Row(
            children: [
              if (leading != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: SizedBox(height: 48, child: Center(child: leading)),
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
                      return TabChip(
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
                        onClose: () => onClose(index),
                        closable: tabs.length > 1,
                        onRename: tab.canRename ? () {} : null,
                        dragIndex: tab.canDrag ? index : null,
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
