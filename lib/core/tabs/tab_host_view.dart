import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'tab_host.dart';
import '../navigation/window_controls_constants.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/window_drag_region.dart';

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
    this.enableWindowDrag = true,
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
  final bool enableWindowDrag;

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
      enableWindowDrag: widget.enableWindowDrag,
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
    this.enableWindowDrag = true,
  });

  final List<T> tabs;
  final double tabBarHeight;
  final Widget? leading;
  final VoidCallback? onAddTab;
  final void Function(int oldIndex, int newIndex)? onReorder;
  final Widget Function(BuildContext context, int index, T tab) buildChip;
  final bool enableWindowDrag;

  @override
  State<_TabBarRow<T>> createState() => _TabBarRowState<T>();
}

class _TabBarRowState<T> extends State<_TabBarRow<T>> {
  late final ScrollController _scrollController;
  bool _hasOverflow = false;
  bool _hoveringBar = false;
  bool _touchScrolling = false;
  bool _reschedulePending = false;
  bool _overflowUpdateScheduled = false;
  bool? _pendingOverflow;
  bool _touchUpdateScheduled = false;
  bool? _pendingTouchScrolling;
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
    final overflow = max > 0.5;
    if (_hasOverflow != overflow) {
      _scheduleOverflowUpdate(overflow);
    }
  }

  bool _handleMetrics(ScrollMetrics metrics) {
    final max = metrics.maxScrollExtent;
    final overflow = max > 0.5;
    if (_hasOverflow != overflow) {
      _scheduleOverflowUpdate(overflow);
    }
    return false;
  }

  void _scheduleOverflowUpdate(bool overflow) {
    _pendingOverflow = overflow;
    if (_overflowUpdateScheduled) {
      return;
    }
    _overflowUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _overflowUpdateScheduled = false;
      final next = _pendingOverflow;
      _pendingOverflow = null;
      if (!mounted || next == null || _hasOverflow == next) {
        return;
      }
      if (!next && _scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
      if (kDebugMode) {
        debugPrint(
          '[TabHostView] overflow=${next ? 'on' : 'off'} '
          'scrollbar=${next ? 'visible' : 'hidden'} '
          'pinnedAdd=${widget.onAddTab != null && next ? 'on' : 'off'}',
        );
      }
      setState(() => _hasOverflow = next);
    });
  }

  bool _handleScrollActivity(ScrollNotification notification) {
    if (notification is ScrollStartNotification ||
        notification is ScrollUpdateNotification) {
      _scrollHideTimer?.cancel();
      if (!_touchScrolling) {
        _scheduleTouchScrollingUpdate(true);
      }
    } else if (notification is ScrollEndNotification) {
      _scrollHideTimer?.cancel();
      _scrollHideTimer = Timer(const Duration(milliseconds: 400), () {
        if (mounted && _touchScrolling) {
          _scheduleTouchScrollingUpdate(false);
        }
      });
    }
    return false;
  }

  void _scheduleTouchScrollingUpdate(bool value) {
    _pendingTouchScrolling = value;
    if (_touchUpdateScheduled) {
      return;
    }
    _touchUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _touchUpdateScheduled = false;
      final next = _pendingTouchScrolling;
      _pendingTouchScrolling = null;
      if (!mounted || next == null || _touchScrolling == next) {
        return;
      }
      setState(() => _touchScrolling = next);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tabs = widget.tabs;
    final spacing = context.appTheme.spacing;
    final tabBarHeight = widget.tabBarHeight;
    final leading = widget.leading;
    final onAddTab = widget.onAddTab;
    final onReorder = widget.onReorder;
    final buildChip = widget.buildChip;

    final hasAddTab = onAddTab != null;
    final colorScheme = Theme.of(context).colorScheme;
    final toolbarColor = context.appTheme.section.toolbarBackground;

    // Match height to window controls when custom chrome is enabled
    final bool useCustomChrome =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.linux);
    final bool enableDrag = useCustomChrome && widget.enableWindowDrag;
    final rightInset = enableDrag
        ? WindowControlsConstants.totalWidth
        : 0.0;
    final dragGutterWidth = enableDrag
        ? WindowControlsConstants.dragRegionWidth
        : 0.0;
    // Match window controls height (32px) when custom chrome is enabled to eliminate dead space
    final effectiveHeight = useCustomChrome
        ? WindowControlsConstants.tabBarHeight
        : tabBarHeight + 2;
    final effectiveTabBarHeight = useCustomChrome
        ? WindowControlsConstants.tabBarHeight
        : tabBarHeight;

    final overlayButtonSize = effectiveTabBarHeight;
    final bool showScrollbar = _hasOverflow;
    final double bottomSpacing = showScrollbar ? spacing.md : 0.0;
    final double scrollbarInset = bottomSpacing;
    final double hoverActionReserve =
        showScrollbar ? spacing.base * 12 : 0.0;
    final bool showHoverActionReserve = showScrollbar;
    final bool activeThumb = showScrollbar && (_hoveringBar || _touchScrolling);
    final bool showThumb = showScrollbar;
    final bool showPinnedAddButton = hasAddTab && _hasOverflow;

    final iconSize = Theme.of(context).iconTheme.size ?? 24.0;
    final topInset = useCustomChrome
        ? (WindowControlsConstants.height - iconSize).clamp(0.0, 6.0) / 2
        : 0.0;

    return Container(
      height: effectiveHeight + scrollbarInset,
      padding: EdgeInsets.only(
        top: topInset,
        bottom: topInset,
        right: rightInset,
      ),
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
          // Match the SectionNavBar spacing when using custom chrome.
          if (leading != null && !useCustomChrome)
            SizedBox(width: spacing.base * 1.5),
          // Tab content area - clip to prevent overflow into button space
          Expanded(
            child: MouseRegion(
              onEnter: (_) {
                _hoverHideTimer?.cancel();
                if (!_hoveringBar) setState(() => _hoveringBar = true);
              },
              onExit: (_) {
                _hoverHideTimer?.cancel();
                _hoverHideTimer = Timer(const Duration(milliseconds: 200), () {
                  if (mounted && _hoveringBar) {
                    setState(() => _hoveringBar = false);
                  }
                });
              },
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Stack(
                      children: [
                      if (enableDrag)
                        const Positioned.fill(
                          child: WindowDragRegion(
                            child: SizedBox.expand(),
                          ),
                        ),
                        ClipRect(
                          child: SizedBox(
                            height: effectiveTabBarHeight + scrollbarInset,
                            child: Padding(
                            padding: EdgeInsets.only(
                              left: 0,
                              right:
                                  (showPinnedAddButton ? overlayButtonSize : 0),
                              bottom: 0,
                            ),
                              child: RawScrollbar(
                                controller: _scrollController,
                                thumbVisibility: showThumb,
                                trackVisibility: showScrollbar,
                                thickness: 6,
                                interactive: true,
                                scrollbarOrientation:
                                    ScrollbarOrientation.bottom,
                                notificationPredicate: (_) => true,
                                radius: const Radius.circular(2),
                                thumbColor: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(
                                      alpha: activeThumb ? 0.9 : 0.0,
                                    ),
                                trackColor: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.08),
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    bottom: bottomSpacing,
                                  ),
                                  child: NotificationListener<
                                      ScrollMetricsNotification>(
                                    onNotification: (notification) =>
                                        _handleMetrics(notification.metrics),
                                    child:
                                        NotificationListener<ScrollNotification>(
                                      onNotification: _handleScrollActivity,
                                      child: ReorderableListView.builder(
                                        scrollController: _scrollController,
                                        scrollDirection: Axis.horizontal,
                                        primary: false,
                                        shrinkWrap: true,
                                        physics: const ClampingScrollPhysics(),
                                        buildDefaultDragHandles: false,
                                        onReorder: onReorder != null
                                            ? (oldIndex, newIndex) {
                                                final cappedIndex =
                                                    newIndex > tabs.length
                                                    ? tabs.length
                                                    : newIndex;
                                                onReorder(
                                                  oldIndex,
                                                  cappedIndex,
                                                );
                                              }
                                            : (oldIndex, newIndex) {},
                                        itemCount:
                                            tabs.length +
                                            (hasAddTab && !showPinnedAddButton
                                                ? 1
                                                : 0) +
                                            (showHoverActionReserve ? 1 : 0),
                                        itemBuilder: (context, index) {
                                          final inlineAddIndex = tabs.length;
                                          final reserveIndex =
                                              inlineAddIndex +
                                              (hasAddTab && !showPinnedAddButton
                                                  ? 1
                                                  : 0);
                                          if (hasAddTab &&
                                              !showPinnedAddButton &&
                                              index == inlineAddIndex) {
                                            return KeyedSubtree(
                                              key: const ValueKey(
                                                'tab-bar-add-inline',
                                              ),
                                              child: _InlineAddButton(
                                                size: overlayButtonSize,
                                                enabled: !showPinnedAddButton,
                                                onTap: onAddTab,
                                              ),
                                            );
                                          }
                                          if (showHoverActionReserve &&
                                              index == reserveIndex) {
                                            return KeyedSubtree(
                                              key: const ValueKey(
                                                'tab-bar-hover-reserve',
                                              ),
                                              child: SizedBox(
                                                width: hoverActionReserve,
                                              ),
                                            );
                                          }
                                          return buildChip(
                                            context,
                                            index,
                                            tabs[index],
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (showPinnedAddButton)
                    Positioned(
                      right: dragGutterWidth,
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
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [color.withValues(alpha: 0.0), color],
        ),
      ),
      child: Tooltip(
        message: 'New tab',
        child: _AddTabSliceButton(size: size, enabled: true, onTap: onTap),
      ),
    );
  }
}

class _InlineAddButton extends StatelessWidget {
  const _InlineAddButton({
    required this.size,
    required this.enabled,
    required this.onTap,
  });

  final double size;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: enabled ? 1 : 0.2,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
      child: IgnorePointer(
        ignoring: !enabled,
        child: SizedBox(
          width: size,
          height: size,
          child: Semantics(
            label: 'New tab',
            button: true,
            child: _AddTabSliceButton(
              size: size,
              enabled: enabled,
              onTap: onTap,
            ),
          ),
        ),
      ),
    );
  }
}

class _AddTabSliceButton extends StatefulWidget {
  const _AddTabSliceButton({
    required this.size,
    required this.enabled,
    required this.onTap,
  });

  final double size;
  final bool enabled;
  final VoidCallback onTap;

  @override
  State<_AddTabSliceButton> createState() => _AddTabSliceButtonState();
}

class _AddTabSliceButtonState extends State<_AddTabSliceButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hoverColor = scheme.onSurface.withValues(alpha: 0.08);
    return MouseRegion(
      cursor: widget.enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => _setHovering(true),
      onExit: (_) => _setHovering(false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: _hovering && widget.enabled ? hoverColor : Colors.transparent,
          borderRadius: BorderRadius.zero,
        ),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.enabled ? widget.onTap : null,
          child: Center(
            child: Icon(Icons.add, size: 18, color: scheme.onSurface),
          ),
        ),
      ),
    );
  }

  void _setHovering(bool value) {
    if (_hovering == value) return;
    setState(() => _hovering = value);
  }
}
