import 'package:flutter/widgets.dart';

import '../../services/logging/app_logger.dart';

typedef MouseScopeHandler = void Function(PointerEvent event);

/// Lightweight scope service mirroring [GestureService] for pointer-driven UX.
class MouseScopeService {
  MouseScopeService._internal();

  static final MouseScopeService instance = MouseScopeService._internal();

  final List<_MouseScope> _scopes = [];

  MouseScopeSubscription registerScope({
    required String id,
    FocusNode? focusNode,
    int priority = 0,
    MouseScopeHandler? onEnter,
    MouseScopeHandler? onExit,
    MouseScopeHandler? onHover,
    MouseScopeHandler? onDown,
    MouseScopeHandler? onUp,
    MouseScopeHandler? onMove,
  }) {
    final scope = _MouseScope(
      id: id,
      focusNode: focusNode,
      priority: priority,
      onEnter: onEnter,
      onExit: onExit,
      onHover: onHover,
      onDown: onDown,
      onUp: onUp,
      onMove: onMove,
    );
    _scopes.add(scope);
    _sort();
    AppLogger.d(
      'registered mouse scope="$id" priority=$priority',
      tag: 'Mouse',
    );
    return MouseScopeSubscription(() {
      _scopes.remove(scope);
      AppLogger.d('disposed mouse scope="$id"', tag: 'Mouse');
    });
  }

  List<MouseScopeSnapshot> snapshots({bool includeInactive = true}) {
    return _scopes
        .where((scope) => includeInactive || scope.active)
        .map((s) => s.snapshot())
        .toList();
  }

  Widget wrap(String id, Widget child) {
    final scope = _scopes.firstWhere(
      (s) => s.id == id,
      orElse: () => _MouseScope(id: id),
    );
    return MouseRegion(
      onEnter: scope.onEnter,
      onExit: scope.onExit,
      onHover: scope.onHover,
      child: Listener(
        onPointerDown: scope.onDown,
        onPointerUp: scope.onUp,
        onPointerMove: scope.onMove,
        child: child,
      ),
    );
  }

  void _sort() {
    _scopes.sort((a, b) => b.priority.compareTo(a.priority));
  }
}

class _MouseScope {
  _MouseScope({
    required this.id,
    this.focusNode,
    this.priority = 0,
    this.onEnter,
    this.onExit,
    this.onHover,
    this.onDown,
    this.onUp,
    this.onMove,
  });

  final String id;
  final FocusNode? focusNode;
  final int priority;
  final MouseScopeHandler? onEnter;
  final MouseScopeHandler? onExit;
  final MouseScopeHandler? onHover;
  final MouseScopeHandler? onDown;
  final MouseScopeHandler? onUp;
  final MouseScopeHandler? onMove;

  bool get active {
    final node = focusNode;
    if (node == null) return true;
    return node.hasFocus || node.hasPrimaryFocus;
  }

  MouseScopeSnapshot snapshot() {
    return MouseScopeSnapshot(
      id: id,
      priority: priority,
      active: active,
      usesFocus: focusNode != null,
    );
  }
}

class MouseScopeSubscription {
  MouseScopeSubscription(this._dispose);
  final VoidCallback _dispose;
  void dispose() => _dispose();
}

class MouseScopeSnapshot {
  const MouseScopeSnapshot({
    required this.id,
    required this.priority,
    required this.active,
    required this.usesFocus,
  });

  final String id;
  final int priority;
  final bool active;
  final bool usesFocus;
}
