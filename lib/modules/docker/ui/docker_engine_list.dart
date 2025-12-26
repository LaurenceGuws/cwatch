import 'package:flutter/material.dart';

import 'package:cwatch/models/ssh_host.dart';
import 'package:cwatch/shared/theme/app_theme.dart';
import 'package:cwatch/shared/theme/nerd_fonts.dart';
import 'package:cwatch/shared/views/shared/tabs/tab_chip.dart';
import 'engine_tab.dart';
import 'package:cwatch/shared/views/shared/tab_list_host.dart';

class DockerEngineList extends StatelessWidget implements TabListHost {
  const DockerEngineList({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onSelect,
    required this.onClose,
    required this.onReorder,
    this.leading,
    this.onAddTab,
    this.tabContents,
  });

  @override
  final List<EngineTab> tabs;
  @override
  final int selectedIndex;
  @override
  final ValueChanged<int> onSelect;
  @override
  final ValueChanged<int> onClose;
  @override
  final void Function(int oldIndex, int newIndex) onReorder;
  @override
  final Widget? leading;
  @override
  final VoidCallback? onAddTab;
  final List<Widget>? tabContents;

  @override
  Widget build(BuildContext context) {
    final appTheme = context.appTheme;
    final spacing = appTheme.spacing;
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
                  padding: EdgeInsets.symmetric(horizontal: spacing.sm),
                  child: SizedBox(height: 36, child: Center(child: leading)),
                ),
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: ReorderableListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(horizontal: spacing.md),
                    buildDefaultDragHandles: false,
                    onReorder: onReorder,
                    itemCount: tabs.length,
                    itemBuilder: (context, index) {
                      final tab = tabs[index];
                      final optionsController = tab.optionsController;
                      Widget buildTab(List<TabChipOption> options) {
                        return TabChip(
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
                          closable: true,
                          onRename: tab.canRename ? () {} : null,
                          dragIndex: tab.canDrag ? index : null,
                          options: options,
                        );
                      }

                      if (optionsController == null) {
                        return KeyedSubtree(
                          key: ValueKey(tab.id),
                          child: buildTab(const []),
                        );
                      }
                      return ValueListenableBuilder<List<TabChipOption>>(
                        key: ValueKey(tab.id),
                        valueListenable: optionsController,
                        builder: (context, options, _) => buildTab(options),
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
            children:
                tabContents ??
                (tabs.isEmpty
                    ? [const SizedBox.shrink()]
                    : tabs.map((tab) => tab.body).toList()),
          ),
        ),
      ],
    );
  }
}
