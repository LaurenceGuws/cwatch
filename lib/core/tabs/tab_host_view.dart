import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'tab_host.dart';

/// Simple wrapper that renders a tab bar and content stack using a
/// TabHostController. Modules supply a tab list, chip builder, and body builder.
class TabHostView<T> extends StatefulWidget {
  const TabHostView({
    super.key,
    required this.controller,
    required this.buildChip,
    required this.buildBody,
    required this.tabId,
    this.leading,
    this.onReorder,
    this.onAddTab,
    this.tabBarHeight = 36,
    this.showTabBar,
  });

  final TabHostController<T> controller;
  final Widget? leading;
  final Widget Function(BuildContext context, int index, T tab) buildChip;
  final Widget Function(T tab) buildBody;
  final String Function(T tab) tabId;
  final void Function(int oldIndex, int newIndex)? onReorder;
  final VoidCallback? onAddTab;
  final double tabBarHeight;
  final ValueListenable<bool>? showTabBar;

  @override
  State<TabHostView<T>> createState() => _TabHostViewState<T>();
}

class _TabHostViewState<T> extends State<TabHostView<T>> {
  final Set<String> _mountedIds = {};
  late final VoidCallback _listener;

  @override
  void initState() {
    super.initState();
    _listener = _syncMounted;
    widget.controller.addListener(_listener);
    _syncMounted();
  }

  @override
  void didUpdateWidget(covariant TabHostView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_listener);
      widget.controller.addListener(_listener);
      _mountedIds.clear();
      _syncMounted();
    } else {
      _syncMounted();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_listener);
    super.dispose();
  }

  void _syncMounted() {
    final tabs = widget.controller.tabs;
    if (tabs.isEmpty) {
      return;
    }
    final selectedIndex = widget.controller.selectedIndex.clamp(
      0,
      tabs.length - 1,
    );
    if (selectedIndex >= 0 && selectedIndex < tabs.length) {
      _mountedIds.add(widget.tabId(tabs[selectedIndex]));
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final tabs = widget.controller.tabs;
    final selectedIndex = tabs.isEmpty
        ? 0
        : widget.controller.selectedIndex.clamp(0, tabs.length - 1);
    final tabBar = _TabBarRow<T>(
      tabs: tabs,
      tabBarHeight: widget.tabBarHeight,
      leading: widget.leading,
      onAddTab: widget.onAddTab,
      onReorder: widget.onReorder,
      buildChip: widget.buildChip,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showTabBar != null)
          ValueListenableBuilder<bool>(
            valueListenable: widget.showTabBar!,
            builder: (context, visible, _) =>
                visible && tabs.isNotEmpty ? tabBar : const SizedBox.shrink(),
          )
        else
          tabBar,
        Flexible(
          fit: FlexFit.loose,
          child: IndexedStack(
            index: selectedIndex,
            children: List<Widget>.generate(tabs.length, (index) {
              final tab = tabs[index];
              final id = widget.tabId(tab);
              if (_mountedIds.contains(id)) {
                return widget.buildBody(tab);
              }
              return const SizedBox.shrink();
            }, growable: false),
          ),
        ),
      ],
    );
  }
}

class _TabBarRow<T> extends StatelessWidget {
  const _TabBarRow({
    required this.tabs,
    required this.tabBarHeight,
    required this.buildChip,
    this.leading,
    this.onAddTab,
    this.onReorder,
  });

  final List<T> tabs;
  final double tabBarHeight;
  final Widget? leading;
  final VoidCallback? onAddTab;
  final void Function(int oldIndex, int newIndex)? onReorder;
  final Widget Function(BuildContext context, int index, T tab) buildChip;

  @override
  Widget build(BuildContext context) {
    final hasAddTab = onAddTab != null;
    final colorScheme = Theme.of(context).colorScheme;
    final toolbarColor =
        colorScheme.surfaceContainerHighest.withValues(alpha: 0.38);
    return Container(
      height: tabBarHeight + 2,
      padding: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: toolbarColor,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.25),
          ),
        ),
      ),
      child: Row(
        children: [
          if (leading != null) leading!,
          Expanded(
            child: SizedBox(
              height: tabBarHeight,
              child: ReorderableListView.builder(
                scrollDirection: Axis.horizontal,
                buildDefaultDragHandles: false,
                padding: EdgeInsets.zero,
                onReorder: onReorder ?? (oldIndex, newIndex) {},
                itemCount: tabs.length,
                itemBuilder: (context, index) =>
                    buildChip(context, index, tabs[index]),
                footer: hasAddTab
                    ? KeyedSubtree(
                        key: const ValueKey('tab-bar-add'),
                        child: IconButton(
                          tooltip: 'New tab',
                          icon: const Icon(Icons.add),
                          onPressed: onAddTab,
                        ),
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
