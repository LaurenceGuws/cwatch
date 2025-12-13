import 'package:flutter/widgets.dart';

import '../../services/logging/app_logger.dart';

/// Context provided to gesture handlers.
class GestureInvocation {
  GestureInvocation({required this.activator, this.payload});

  final ShortcutActivator activator;
  final Object? payload;

  T? payloadAs<T>() => payload is T ? payload as T : null;
}

/// Handler invoked when a registered gesture is triggered.
typedef GestureHandler = void Function(GestureInvocation invocation);

class GestureSubscription {
  GestureSubscription(this._dispose);

  final VoidCallback _dispose;

  void dispose() => _dispose();
}

class GestureService {
  GestureService._internal();

  static final GestureService instance = GestureService._internal();

  final List<_GestureScope> _scopes = [];

  GestureSubscription registerScope({
    required String id,
    required Map<ShortcutActivator, GestureHandler> handlers,
    FocusNode? focusNode,
    int priority = 0,
  }) {
    final scope = _GestureScope(
      id: id,
      handlers: handlers,
      focusNode: focusNode,
      priority: priority,
    );
    _scopes.add(scope);
    _sortScopes();
    AppLogger.d(
      'registered gesture scope="$id" priority=$priority activators=${handlers.keys.join(', ')}',
      tag: 'Gestures',
    );
    return GestureSubscription(() {
      _scopes.remove(scope);
      AppLogger.d('disposed gesture scope="$id"', tag: 'Gestures');
    });
  }

  /// Dispatches a gesture to the highest-priority active scope.
  bool handle(ShortcutActivator activator, {Object? payload}) {
    for (final scope in _scopes) {
      final handler = scope.handlerFor(activator);
      if (handler != null) {
        handler(GestureInvocation(activator: activator, payload: payload));
        AppLogger.d(
          'handled gesture ${activator.toString()} in scope="${scope.id}"',
          tag: 'Gestures',
        );
        return true;
      }
    }
    AppLogger.d(
      'no gesture handler for ${activator.toString()}',
      tag: 'Gestures',
    );
    return false;
  }

  void _sortScopes() {
    _scopes.sort((a, b) => b.priority.compareTo(a.priority));
  }

  List<GestureScopeSnapshot> snapshots({bool includeInactive = true}) {
    return _scopes
        .where((scope) => includeInactive || scope.active)
        .map((scope) => scope.snapshot())
        .toList();
  }
}

class _GestureScope {
  _GestureScope({
    required this.id,
    required this.handlers,
    required this.focusNode,
    required this.priority,
  }) : _usesFocus = focusNode != null;

  final String id;
  final Map<ShortcutActivator, GestureHandler> handlers;
  final FocusNode? focusNode;
  final int priority;
  final bool _usesFocus;

  bool get active => _hasFocus;

  bool get _hasFocus {
    final node = focusNode;
    if (node == null) return true;
    return node.hasFocus || node.hasPrimaryFocus;
  }

  GestureHandler? handlerFor(ShortcutActivator activator) {
    if (!_hasFocus) return null;
    return handlers[activator];
  }

  GestureScopeSnapshot snapshot() {
    return GestureScopeSnapshot(
      id: id,
      priority: priority,
      active: active,
      usesFocus: _usesFocus,
      activators: handlers.keys.toList(),
    );
  }
}

class GestureScopeSnapshot {
  const GestureScopeSnapshot({
    required this.id,
    required this.priority,
    required this.active,
    required this.usesFocus,
    required this.activators,
  });

  final String id;
  final int priority;
  final bool active;
  final bool usesFocus;
  final List<ShortcutActivator> activators;
}
