import 'package:flutter/widgets.dart';

/// Lightweight registry that caches tab body widgets with keep-alive support,
/// keeping disposal concerns local to the view layer.
class TabViewRegistry<T> {
  TabViewRegistry({
    required this.tabId,
    required this.keepAliveBuilder,
    this.viewKeyPrefix = 'tab',
  });

  final String Function(T tab) tabId;
  final Widget Function(Widget child, GlobalKey key) keepAliveBuilder;
  final String viewKeyPrefix;

  final Map<String, GlobalKey> _keepAliveKeys = {};
  final Map<String, Widget> _tabWidgets = {};

  Widget widgetFor(T tab, Widget Function() bodyBuilder) {
    final id = tabId(tab);
    return _tabWidgets[id] ??= KeyedSubtree(
      key: ValueKey('$viewKeyPrefix-$id'),
      child: keepAliveBuilder(
        bodyBuilder(),
        _keepAliveKeys.putIfAbsent(
          id,
          () => GlobalKey(debugLabel: '$viewKeyPrefix-keepalive-$id'),
        ),
      ),
    );
  }

  void remove(T tab) {
    final id = tabId(tab);
    _tabWidgets.remove(id);
    _keepAliveKeys.remove(id);
  }

  void reset(Iterable<T> tabs) {
    final ids = tabs.map(tabId).toSet();
    _tabWidgets.removeWhere((key, value) => !ids.contains(key));
    _keepAliveKeys.removeWhere((key, value) => !ids.contains(key));
  }

  void clear() {
    _tabWidgets.clear();
    _keepAliveKeys.clear();
  }
}
