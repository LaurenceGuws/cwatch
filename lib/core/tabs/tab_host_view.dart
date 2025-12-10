import 'package:flutter/material.dart';

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
  });

  final TabHostController<T> controller;
  final Widget? leading;
  final Widget Function(BuildContext context, int index, T tab) buildChip;
  final Widget Function(T tab) buildBody;
  final String Function(T tab) tabId;
  final void Function(int oldIndex, int newIndex)? onReorder;
  final VoidCallback? onAddTab;
  final double tabBarHeight;

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
    final selectedIndex =
        tabs.isEmpty ? 0 : widget.controller.selectedIndex.clamp(0, tabs.length - 1);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            if (widget.leading != null) widget.leading!,
            Expanded(
              child: SizedBox(
                height: widget.tabBarHeight,
                child: ReorderableListView.builder(
                  scrollDirection: Axis.horizontal,
                  buildDefaultDragHandles: false,
                  onReorder: widget.onReorder ?? (oldIndex, newIndex) {},
                  itemCount: tabs.length,
                  itemBuilder: (context, index) => widget.buildChip(
                    context,
                    index,
                    tabs[index],
                  ),
                ),
              ),
            ),
            if (widget.onAddTab != null)
              IconButton(
                tooltip: 'New tab',
                icon: const Icon(Icons.add),
                onPressed: widget.onAddTab,
              ),
          ],
        ),
        Flexible(
          fit: FlexFit.loose,
          child: IndexedStack(
            index: selectedIndex,
            children: List<Widget>.generate(
              tabs.length,
              (index) {
                final tab = tabs[index];
                final id = widget.tabId(tab);
                if (_mountedIds.contains(id)) {
                  return widget.buildBody(tab);
                }
                return const SizedBox.shrink();
              },
              growable: false,
            ),
          ),
        ),
      ],
    );
  }
}
