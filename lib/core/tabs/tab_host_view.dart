import 'package:flutter/material.dart';

import 'tab_host.dart';

/// Simple wrapper that renders a tab bar and content stack using a
/// TabHostController. Modules supply a tab list, chip builder, and body builder.
class TabHostView<T> extends StatelessWidget {
  const TabHostView({
    super.key,
    required this.controller,
    required this.buildChip,
    required this.buildBody,
    this.leading,
    this.onReorder,
    this.onAddTab,
    this.tabBarHeight = 36,
  });

  final TabHostController<T> controller;
  final Widget? leading;
  final Widget Function(BuildContext context, int index, T tab) buildChip;
  final Widget Function(T tab) buildBody;
  final void Function(int oldIndex, int newIndex)? onReorder;
  final VoidCallback? onAddTab;
  final double tabBarHeight;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final tabs = controller.tabs;
        final selectedIndex = tabs.isEmpty
            ? 0
            : controller.selectedIndex.clamp(0, tabs.length - 1);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (leading != null) leading!,
                Expanded(
                  child: SizedBox(
                    height: tabBarHeight,
                    child: ReorderableListView.builder(
                      scrollDirection: Axis.horizontal,
                      buildDefaultDragHandles: false,
                      onReorder: onReorder ?? (oldIndex, newIndex) {},
                      itemCount: tabs.length,
                      itemBuilder: (context, index) => buildChip(
                        context,
                        index,
                        tabs[index],
                      ),
                    ),
                  ),
                ),
                if (onAddTab != null)
                  IconButton(
                    tooltip: 'New tab',
                    icon: const Icon(Icons.add),
                    onPressed: onAddTab,
                  ),
              ],
            ),
            Flexible(
              fit: FlexFit.loose,
              child: IndexedStack(
                index: selectedIndex,
                children: tabs.map(buildBody).toList(growable: false),
              ),
            ),
          ],
        );
      },
    );
  }
}
