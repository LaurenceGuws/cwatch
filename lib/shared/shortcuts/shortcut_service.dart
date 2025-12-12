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

  void updateSettings(AppSettings settings) {
    _resolver = ShortcutResolver(settings);
    for (final scope in _scopes) {
      scope.rebuildBindings(_resolver);
    }
  }

  ShortcutSubscription registerScope({
    required String id,
    required Map<String, ShortcutHandler> handlers,
    FocusNode? focusNode,
    int priority = 0,
    bool consumeOnHandle = true,
  }) {
    final scope = _ShortcutScope(
      id: id,
      handlers: handlers,
      priority: priority,
      focusNode: focusNode,
      resolver: _resolver,
      consumeOnHandle: consumeOnHandle,
    );
    _scopes.add(scope);
    _scopes.sort(
      (a, b) => b.priority.compareTo(a.priority),
    );
    AppLogger.d(
      'registered scope="$id" priority=$priority bindings=${scope.bindingLabels.join(', ')}',
      tag: 'Shortcuts',
    );
    return ShortcutSubscription(() {
      _scopes.remove(scope);
      scope.dispose();
      AppLogger.d('disposed scope="$id"', tag: 'Shortcuts');
    });
  }

  bool _onKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) {
      return false;
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
      if (shouldLog) {
        AppLogger.d(
          '  scope=${scope.id} active=${scope.active} bindings=${scope.bindingLabels.join(', ')}',
          tag: 'Shortcuts',
        );
      }
      if (!scope.active) {
        continue;
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
    }
    return false;
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
  })  : focusNode = focusNode ?? FocusNode(skipTraversal: true),
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
}
