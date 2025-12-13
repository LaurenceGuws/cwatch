import 'package:flutter/material.dart';

import '../../core/navigation/command_palette_registry.dart';
import '../../models/app_settings.dart';
import '../../shared/gestures/gesture_activators.dart';
import '../../shared/gestures/gesture_service.dart';
import '../../shared/shortcuts/input_mode_resolver.dart';
import '../../shared/shortcuts/shortcut_definition.dart';
import '../../shared/shortcuts/shortcut_resolver.dart';
import '../../shared/shortcuts/shortcut_service.dart';

class _ScopeSummary {
  _ScopeSummary({
    required this.id,
    required this.priority,
    required this.usesFocus,
    required this.active,
  });

  final String id;
  int priority;
  bool usesFocus;
  bool active;
  final List<ShortcutScopeBinding> shortcuts = [];
  final List<ShortcutActivator> gestures = [];
}

Future<void> showInputHelpDialog(
  BuildContext context, {
  required AppSettings settings,
  required String moduleId,
}) async {
  final platform = Theme.of(context).platform;
  final inputMode = resolveInputMode(settings.inputModePreference, platform);
  final scopeMap = <String, _ScopeSummary>{};

  void mergeSummary({
    required String id,
    required bool usesFocus,
    required bool active,
    required int priority,
    List<ShortcutScopeBinding> shortcuts = const [],
    List<ShortcutActivator> gestures = const [],
  }) {
    final existing = scopeMap[id];
    if (existing != null) {
      existing.priority = existing.priority > priority
          ? existing.priority
          : priority;
      existing.usesFocus = existing.usesFocus || usesFocus;
      existing.active = existing.active || active;
      existing.shortcuts.addAll(shortcuts);
      existing.gestures.addAll(gestures);
      return;
    }
    final summary =
        _ScopeSummary(
            id: id,
            priority: priority,
            usesFocus: usesFocus,
            active: active,
          )
          ..shortcuts.addAll(shortcuts)
          ..gestures.addAll(gestures);
    scopeMap[id] = summary;
  }

  for (final scope in ShortcutService.instance.snapshots()) {
    mergeSummary(
      id: scope.id,
      usesFocus: scope.usesFocus,
      active: scope.active,
      priority: scope.priority,
      shortcuts: scope.bindings,
    );
  }
  for (final scope in GestureService.instance.snapshots()) {
    mergeSummary(
      id: scope.id,
      usesFocus: scope.usesFocus,
      active: scope.active,
      priority: scope.priority,
      gestures: scope.activators,
    );
  }

  List<_ScopeSummary> filterScopes(bool usesFocus) {
    final list = scopeMap.values
        .where((scope) => scope.usesFocus == usesFocus)
        .toList();
    list.sort((a, b) => b.priority.compareTo(a.priority));
    return list;
  }

  String describeBinding(ShortcutScopeBinding binding) {
    final label =
        ShortcutCatalog.find(binding.actionId)?.label ?? binding.actionId;
    final keyLabel = binding.binding.toConfigString();
    return '$label — $keyLabel';
  }

  String describeGesture(ShortcutActivator activator) {
    if (activator is GestureActivator) {
      final def = GestureCatalog.find(activator);
      final label = def?.label ?? (activator.label ?? activator.id);
      final detail = def?.description ?? '';
      return detail.isEmpty ? label : '$label — $detail';
    }
    return activator.toString();
  }

  Widget buildScopeTile(_ScopeSummary scope) {
    final shortcutLabels = scope.shortcuts
        .map(describeBinding)
        .map((label) => Chip(label: Text(label)))
        .toList();
    final gestureLabels = scope.gestures
        .map(describeGesture)
        .map((label) => Chip(label: Text(label)))
        .toList();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${scope.id}${scope.active ? ' (active)' : ' (inactive)'}',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          if (shortcutLabels.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 8, children: shortcutLabels),
          ],
          if (gestureLabels.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 8, children: gestureLabels),
          ],
        ],
      ),
    );
  }

  final contextualScopes = filterScopes(true);
  final globalScopes = filterScopes(false);
  final moduleHandle = CommandPaletteRegistry.instance
      .forModule(moduleId)
      ?.loader;
  final resolver = ShortcutResolver(settings);
  final resolvedBindings = resolver.bindingsForIds(
    ShortcutCatalog.definitions.map((d) => d.id),
  );

  await showDialog<void>(
    context: context,
    builder: (context) {
      final theme = Theme.of(context);
      return AlertDialog(
        title: const Text('Input, shortcuts, and gestures'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Preference: ${settings.inputModePreference.name} · '
                  'Resolved: gestures ${inputMode.enableGestures ? "on" : "off"}, '
                  'shortcuts ${inputMode.enableShortcuts ? "on" : "off"}',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                if (moduleHandle != null)
                  Text('Module: $moduleId', style: theme.textTheme.bodyMedium),
                if (contextualScopes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('Current context', style: theme.textTheme.titleMedium),
                  ...contextualScopes.map(buildScopeTile),
                ],
                if (globalScopes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Global', style: theme.textTheme.titleMedium),
                  ...globalScopes.map(buildScopeTile),
                ],
                const SizedBox(height: 12),
                Text('Bindings', style: theme.textTheme.titleMedium),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: resolvedBindings.entries
                      .map(
                        (entry) => Chip(
                          label: Text(
                            '${ShortcutCatalog.find(entry.key)?.label ?? entry.key} — ${entry.value.toConfigString()}',
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}
