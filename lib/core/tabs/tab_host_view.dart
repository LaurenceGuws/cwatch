import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'tab_host.dart';
import '../navigation/window_controls_constants.dart';

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

class _TabBarRow<T> extends StatefulWidget {
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
  State<_TabBarRow<T>> createState() => _TabBarRowState<T>();
}

class _TabBarRowState<T> extends State<_TabBarRow<T>> {
  late final ScrollController _scrollController;
  bool _hasOverflow = false;
  bool _hoveringBar = false;
  bool _touchScrolling = false;
  bool _reschedulePending = false;
  Timer? _hoverHideTimer;
  Timer? _scrollHideTimer;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_updateScrollState);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateScrollState());
  }

  @override
  void didUpdateWidget(covariant _TabBarRow<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateScrollState());
  }

  @override
  void dispose() {
    _hoverHideTimer?.cancel();
    _scrollHideTimer?.cancel();
    _scrollController
      ..removeListener(_updateScrollState)
      ..dispose();
    super.dispose();
  }

  void _updateScrollState() {
    if (!_scrollController.hasClients) {
      if (!_reschedulePending) {
        _reschedulePending = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _reschedulePending = false;
          _updateScrollState();
        });
      }
      return;
    }
    final position = _scrollController.position;
    final max = position.maxScrollExtent;
    final viewport = position.viewportDimension;
    final overflow = max > viewport + 0.5;
    if (_hasOverflow != overflow) {
      setState(() {
        _hasOverflow = overflow;
      });
    }
  }

  bool _handleMetrics(ScrollMetrics metrics) {
    final max = metrics.maxScrollExtent;
    final overflow = max > metrics.viewportDimension + 0.5;
    if (_hasOverflow != overflow) {
      setState(() {
        _hasOverflow = overflow;
      });
    }
    return false;
  }

  bool _handleScrollActivity(ScrollNotification notification) {
    if (notification is ScrollStartNotification ||
        notification is ScrollUpdateNotification) {
      _scrollHideTimer?.cancel();
      if (!_touchScrolling) setState(() => _touchScrolling = true);
    } else if (notification is ScrollEndNotification) {
      _scrollHideTimer?.cancel();
      _scrollHideTimer = Timer(const Duration(milliseconds: 400), () {
        if (mounted && _touchScrolling) {
          setState(() => _touchScrolling = false);
        }
      });
    }
    return false;
  }



  @override
  Widget build(BuildContext context) {
    final tabs = widget.tabs;
    final tabBarHeight = widget.tabBarHeight;
    final leading = widget.leading;
    final onAddTab = widget.onAddTab;
    final onReorder = widget.onReorder;
    final buildChip = widget.buildChip;

    final hasAddTab = onAddTab != null;
    final colorScheme = Theme.of(context).colorScheme;
    final toolbarColor =
        colorScheme.surfaceContainerHighest.withValues(alpha: 0.38);
    
    // Match height to window controls when custom chrome is enabled
    final bool useCustomChrome = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.linux);
    final rightInset =
        useCustomChrome ? WindowControlsConstants.totalWidth : 0.0;
    // Match window controls height (32px) when custom chrome is enabled to eliminate dead space
    final effectiveHeight = useCustomChrome 
        ? WindowControlsConstants.height 
        : tabBarHeight + 2;
    final effectiveTabBarHeight = useCustomChrome 
        ? WindowControlsConstants.height 
        : tabBarHeight;
    
    final overlayButtonSize = effectiveTabBarHeight;
    final bool showScrollbar = _hasOverflow;
    final double bottomSpacing = showScrollbar ? 8.0 : 0.0;
    final bool activeThumb = showScrollbar && (_hoveringBar || _touchScrolling);
    final bool showThumb = activeThumb;

    return Container(
      height: effectiveHeight,
      padding: EdgeInsets.zero,
      // Keep background spanning the full width, but inset content so it doesn't sit
      // underneath the native window buttons when custom chrome is active.
      decoration: BoxDecoration(
        color: toolbarColor,
        border: useCustomChrome 
            ? null 
            : Border(
                bottom: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.25),
                ),
              ),
      ),
      child: Row(
        children: [
          // Leading button stays at normal position (not translated)
          if (leading != null) leading,
          // Buffer between sidebar button and first tab
          if (leading != null) const SizedBox(width: 6),
          // Tab content area - clip to prevent overflow into button space
          Expanded(
            child: MouseRegion(
              onEnter: (_) {
                _hoverHideTimer?.cancel();
                if (!_hoveringBar) setState(() => _hoveringBar = true);
              },
              onExit: (_) {
                _hoverHideTimer?.cancel();
                _hoverHideTimer = Timer(
                  const Duration(milliseconds: 200),
                  () {
                    if (mounted && _hoveringBar) {
                      setState(() => _hoveringBar = false);
                    }
                  },
                );
              },
              child: Stack(
                children: [
                  ClipRect(
                    child: SizedBox(
                      height: effectiveTabBarHeight,
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: 0,
                          right: (hasAddTab ? overlayButtonSize : 0) +
                              rightInset,
                          bottom: bottomSpacing,
                        ),
                        child: RawScrollbar(
                          controller: _scrollController,
                          thumbVisibility: showThumb,
                          trackVisibility: showScrollbar,
                          thickness: 6,
                          interactive: true,
                          scrollbarOrientation: ScrollbarOrientation.bottom,
                          notificationPredicate: (_) => true,
                          radius: const Radius.circular(3),
                          thumbColor: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: activeThumb ? 0.9 : 0.45),
                          trackColor: Colors.white.withValues(alpha: 0.08),
                        child:
                            NotificationListener<ScrollMetricsNotification>(
                          onNotification: (notification) =>
                              _handleMetrics(notification.metrics),
                          child: NotificationListener<ScrollNotification>(
                            onNotification: _handleScrollActivity,
                            child: ReorderableListView.builder(
                              scrollController: _scrollController,
                              scrollDirection: Axis.horizontal,
                              primary: false,
                              physics: const ClampingScrollPhysics(),
                              buildDefaultDragHandles: false,
                              onReorder: onReorder ?? (oldIndex, newIndex) {},
                              itemCount: tabs.length,
                              itemBuilder: (context, index) =>
                                  buildChip(context, index, tabs[index]),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                  if (hasAddTab)
                    Positioned(
                      right: rightInset,
                      top: 0,
                      bottom: 0,
                      child: KeyedSubtree(
                        key: const ValueKey('tab-bar-add'),
                        child: _PinnedAddButton(
                          size: overlayButtonSize,
                          color: toolbarColor,
                          onTap: onAddTab,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PinnedAddButton extends StatelessWidget {
  const _PinnedAddButton({
    required this.size,
    required this.color,
    required this.onTap,
  });

  final double size;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            color.withValues(alpha: 0.0),
            color,
          ],
        ),
      ),
      child: Tooltip(
        message: 'New tab',
        child: InkWell(
          onTap: onTap,
          child: Icon(Icons.add, size: 18, color: scheme.onSurface),
        ),
      ),
    );
  }
}
