import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../models/app_settings.dart';
import 'shortcut_binding.dart';
import 'shortcut_resolver.dart';
import '../../services/logging/app_logger.dart';

typedef ShortcutHandler = void Function();

class ShortcutSubscription {
  ShortcutSubscription(this._dispose);
  final VoidCallback _dispose;
  void dispose() => _dispose();
}

class ShortcutService {
  ShortcutService._internal() {
    HardwareKeyboard.instance.addHandler(_onKeyEvent);
  }

  static final ShortcutService instance = ShortcutService._internal();

  ShortcutResolver _resolver = const ShortcutResolver(null);

  final List<_ShortcutScope> _scopes = [];
  final Map<FocusNode, VoidCallback> _nodeDisposers = {};
  KeyEvent? _suppressedEvent;

  void updateSettings(AppSettings settings) {
    _resolver = ShortcutResolver(settings);
    for (final scope in _scopes) {
      scope.rebuildBindings(_resolver);
    }
  }

  bool shouldSuppressEvent(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return false;
    }
    final binding = ShortcutBinding.fromKeyEvent(event);
    if (binding == null) {
      return false;
    }
    for (final scope in _scopes) {
      if (!scope.active) {
        continue;
      }
      if (scope.handlerFor(binding) != null) {
        return scope.consumeOnHandle;
      }
    }
    return false;
  }

  ShortcutSubscription registerScope({
    required String id,
    required Map<String, ShortcutHandler> handlers,
    FocusNode? focusNode,
    int priority = 0,
    bool consumeOnHandle = true,
  }) {
    final node = focusNode;
    final scope = _ShortcutScope(
      id: id,
      handlers: handlers,
      priority: priority,
      focusNode: focusNode,
      resolver: _resolver,
      consumeOnHandle: consumeOnHandle,
    );
    _scopes.add(scope);
    _scopes.sort((a, b) => b.priority.compareTo(a.priority));
    AppLogger.d(
      'registered scope="$id" priority=$priority bindings=${scope.bindingLabels.join(', ')}',
      tag: 'Shortcuts',
    );
    if (node != null) {
      _attachNodeListener(node);
    }
    return ShortcutSubscription(() {
      _scopes.remove(scope);
      scope.dispose();
      if (node != null) {
        _detachNodeListener(node);
      }
      AppLogger.d('disposed scope="$id"', tag: 'Shortcuts');
    });
  }

  bool _onKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return false;
    }
    if (identical(event, _suppressedEvent)) {
      _suppressedEvent = null;
      return true;
    }
    final binding = ShortcutBinding.fromKeyEvent(event);
    if (binding == null) {
      return false;
    }

    final isChord = [
      binding.control,
      binding.shift,
      binding.alt,
      binding.meta,
    ].any((v) => v);
    final shouldLog = isChord;
    if (shouldLog) {
      final label = binding.toConfigString();
      AppLogger.d(
        'key=$label ctrl=${binding.control} shift=${binding.shift} alt=${binding.alt} meta=${binding.meta} keyId=${binding.key.keyId}',
        tag: 'Shortcuts',
      );
    }

    for (final scope in _scopes) {
      if (_handleBinding(binding, scope, shouldLog)) {
        return true;
      }
    }
    return false;
  }

  List<ShortcutScopeSnapshot> snapshots({bool includeInactive = true}) {
    return _scopes
        .where((scope) => includeInactive || scope.active)
        .map((scope) => scope.snapshot())
        .toList();
  }

  bool _handleBinding(
    ShortcutBinding binding,
    _ShortcutScope scope,
    bool shouldLog,
  ) {
    if (shouldLog) {
      AppLogger.d(
        '  scope=${scope.id} active=${scope.active} bindings=${scope.bindingLabels.join(', ')}',
        tag: 'Shortcuts',
      );
    }
    if (!scope.active) {
      return false;
    }
    final handler = scope.handlerFor(binding);
    if (handler != null) {
      if (shouldLog) {
        final handledLabel = binding.toConfigString();
        AppLogger.d('${scope.id} handled $handledLabel', tag: 'Shortcuts');
      }
      handler();
      return scope.consumeOnHandle;
    }
    if (shouldLog) {
      AppLogger.d(
        '  ${scope.id} no match (incoming keyId=${binding.key.keyId})',
        tag: 'Shortcuts',
      );
    }
    return false;
  }

  void _attachNodeListener(FocusNode node) {
    if (_nodeDisposers.containsKey(node)) return;
    final previous = node.onKeyEvent;
    KeyEventResult listener(FocusNode node, KeyEvent event) {
      if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
        return previous?.call(node, event) ?? KeyEventResult.ignored;
      }
      final binding = ShortcutBinding.fromKeyEvent(event);
      if (binding != null) {
        for (final scope in _scopes.where((s) => s.focusNode == node)) {
          final handled = _handleBinding(binding, scope, false);
          if (handled) {
            _suppressedEvent = event;
            return scope.consumeOnHandle
                ? KeyEventResult.handled
                : KeyEventResult.skipRemainingHandlers;
          }
        }
      }
      return previous?.call(node, event) ?? KeyEventResult.ignored;
    }

    node.onKeyEvent = listener;
    _nodeDisposers[node] = () {
      if (identical(node.onKeyEvent, listener)) {
        node.onKeyEvent = previous;
      }
    };
  }

  void _detachNodeListener(FocusNode node) {
    final disposer = _nodeDisposers.remove(node);
    disposer?.call();
  }
}

class _ShortcutScope {
  _ShortcutScope({
    required this.id,
    required this.handlers,
    required this.priority,
    required this.consumeOnHandle,
    required ShortcutResolver resolver,
    FocusNode? focusNode,
  }) : focusNode = focusNode ?? FocusNode(skipTraversal: true),
       _ownsFocusNode = focusNode == null {
    _usesFocus = !_ownsFocusNode;
    _focusListener = () {
      _active = _usesFocus ? this.focusNode.hasFocus : true;
    };
    if (_usesFocus) {
      this.focusNode.addListener(_focusListener);
      _active = this.focusNode.hasFocus;
    } else {
      _active = true;
    }
    rebuildBindings(resolver);
  }

  final String id;
  final Map<String, ShortcutHandler> handlers;
  final int priority;
  final FocusNode focusNode;
  late final VoidCallback _focusListener;
  bool _active = true;
  final bool _ownsFocusNode;
  late final bool _usesFocus;

  bool get active => _active;

  final Map<ShortcutBinding, ShortcutHandler> _resolved = {};
  final Map<ShortcutBinding, String> _resolvedIds = {};
  final bool consumeOnHandle;

  Iterable<String> get bindingLabels =>
      _resolved.keys.map((b) => b.toConfigString());

  void rebuildBindings(ShortcutResolver resolver) {
    _resolved.clear();
    _resolvedIds.clear();
    for (final entry in handlers.entries) {
      final binding = resolver.bindingFor(entry.key);
      if (binding == null) continue;
      if (_resolved.containsKey(binding)) {
        final existing = _resolvedIds[binding] ?? 'unknown';
        AppLogger.w(
          'Binding conflict in scope="$id": ${binding.toConfigString()} already used by "$existing", skipping "${entry.key}"',
          tag: 'Shortcuts',
        );
        continue;
      }
      _resolved[binding] = entry.value;
      _resolvedIds[binding] = entry.key;
    }
    AppLogger.d(
      '  rebuilt scope="$id" bindings=${bindingLabels.join(', ')}',
      tag: 'Shortcuts',
    );
  }

  ShortcutHandler? handlerFor(ShortcutBinding binding) {
    return _resolved[binding];
  }

  void dispose() {
    if (_usesFocus) {
      focusNode.removeListener(_focusListener);
    }
    if (_ownsFocusNode) {
      focusNode.dispose();
    }
  }

  ShortcutScopeSnapshot snapshot() {
    return ShortcutScopeSnapshot(
      id: id,
      priority: priority,
      active: active,
      usesFocus: _usesFocus,
      consumeOnHandle: consumeOnHandle,
      bindings: _resolvedIds.entries
          .map(
            (entry) =>
                ShortcutScopeBinding(actionId: entry.value, binding: entry.key),
          )
          .toList(),
    );
  }
}

class ShortcutScopeSnapshot {
  const ShortcutScopeSnapshot({
    required this.id,
    required this.priority,
    required this.active,
    required this.usesFocus,
    required this.consumeOnHandle,
    required this.bindings,
  });

  final String id;
  final int priority;
  final bool active;
  final bool usesFocus;
  final bool consumeOnHandle;
  final List<ShortcutScopeBinding> bindings;
}

class ShortcutScopeBinding {
  const ShortcutScopeBinding({required this.actionId, required this.binding});
  final String actionId;
  final ShortcutBinding binding;
}
