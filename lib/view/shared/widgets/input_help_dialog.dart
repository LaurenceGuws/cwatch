import 'package:flutter/material.dart';

import 'package:cwatch/view/core/navigation/command_palette_registry.dart';
import 'package:cwatch/model/models/app_settings.dart';
import 'package:cwatch/model/shared/gestures/gesture_activators.dart';
import 'package:cwatch/model/shared/gestures/gesture_service.dart';
import 'package:cwatch/model/shared/shortcuts/input_mode_resolver.dart';
import 'package:cwatch/model/shared/shortcuts/shortcut_definition.dart';
import 'package:cwatch/model/shared/shortcuts/shortcut_resolver.dart';
import 'package:cwatch/model/shared/shortcuts/shortcut_service.dart';
import 'package:cwatch/model/shared/theme/app_theme.dart';

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

class _HelpSection extends StatelessWidget {
  const _HelpSection({
    required this.title,
    this.subtitle,
    required this.child,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appTheme.spacing;
    final theme = Theme.of(context);
    return Container(
      margin: EdgeInsets.only(bottom: spacing.lg),
      padding: spacing.inset(horizontal: 1, vertical: 0.9),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(context.scale(14)),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          if (subtitle != null) ...[
            SizedBox(height: spacing.xs),
            Text(subtitle!, style: theme.textTheme.bodySmall),
          ],
          SizedBox(height: spacing.md),
          child,
        ],
      ),
    );
  }
}

class _HelpToken extends StatelessWidget {
  const _HelpToken({required this.label, this.icon, this.tone});

  final String label;
  final IconData? icon;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appTheme.spacing;
    final theme = Theme.of(context);
    final color = tone ?? theme.colorScheme.primary;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.md,
        vertical: spacing.sm,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(context.scale(999)),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            SizedBox(width: spacing.xs),
          ],
          Flexible(
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
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
    return '$label - $keyLabel';
  }

  String describeGesture(ShortcutActivator activator) {
    if (activator is GestureActivator) {
      final def = GestureCatalog.find(activator);
      final label = def?.label ?? (activator.label ?? activator.id);
      final detail = def?.description ?? '';
      return detail.isEmpty ? label : '$label - $detail';
    }
    return activator.toString();
  }

  Widget buildScopeTile(BuildContext context, _ScopeSummary scope) {
    final spacing = context.appTheme.spacing;
    final theme = Theme.of(context);
    final shortcutLabels = scope.shortcuts
        .map(describeBinding)
        .map((label) => _HelpToken(label: label, icon: Icons.keyboard))
        .toList();
    final gestureLabels = scope.gestures
        .map(describeGesture)
        .map(
          (label) => _HelpToken(
            label: label,
            icon: Icons.touch_app,
            tone: theme.colorScheme.tertiary,
          ),
        )
        .toList();
    final stateColor = scope.active
        ? theme.colorScheme.primary
        : theme.colorScheme.outline;
    return Container(
      margin: EdgeInsets.only(bottom: spacing.md),
      padding: spacing.inset(horizontal: 0.8, vertical: 0.75),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(context.scale(12)),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(scope.id, style: theme.textTheme.titleSmall),
              ),
              _HelpToken(
                label: scope.active ? 'Active' : 'Inactive',
                tone: stateColor,
              ),
            ],
          ),
          if (shortcutLabels.isNotEmpty) ...[
            SizedBox(height: spacing.md),
            Text('Shortcuts', style: theme.textTheme.labelMedium),
            SizedBox(height: spacing.sm),
            Wrap(
              spacing: spacing.sm,
              runSpacing: spacing.sm,
              children: shortcutLabels,
            ),
          ],
          if (gestureLabels.isNotEmpty) ...[
            SizedBox(height: spacing.md),
            Text('Gestures', style: theme.textTheme.labelMedium),
            SizedBox(height: spacing.sm),
            Wrap(
              spacing: spacing.sm,
              runSpacing: spacing.sm,
              children: gestureLabels,
            ),
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
      final spacing = context.appTheme.spacing;
      final summaryTokens = <Widget>[
        _HelpToken(
          label: 'Mode: ${settings.inputModePreference.name}',
          icon: Icons.tune,
        ),
        _HelpToken(
          label: 'Gestures ${inputMode.enableGestures ? "on" : "off"}',
          icon: Icons.touch_app,
          tone: inputMode.enableGestures
              ? theme.colorScheme.tertiary
              : theme.colorScheme.outline,
        ),
        _HelpToken(
          label: 'Shortcuts ${inputMode.enableShortcuts ? "on" : "off"}',
          icon: Icons.keyboard,
          tone: inputMode.enableShortcuts
              ? theme.colorScheme.primary
              : theme.colorScheme.outline,
        ),
      ];
      if (moduleHandle != null) {
        summaryTokens.add(
          _HelpToken(
            label: 'Module: $moduleId',
            icon: Icons.widgets_outlined,
            tone: theme.colorScheme.secondary,
          ),
        );
      }

      return AlertDialog(
        title: const Text('Input, shortcuts, and gestures'),
        content: SizedBox(
          width: context.scale(620),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HelpSection(
                  title: 'Current input setup',
                  subtitle:
                      'This view combines your current input preference with the shortcuts and gestures registered in the active shell scopes.',
                  child: Wrap(
                    spacing: spacing.sm,
                    runSpacing: spacing.sm,
                    children: summaryTokens,
                  ),
                ),
                if (contextualScopes.isNotEmpty)
                  _HelpSection(
                    title: 'Current context',
                    subtitle:
                        'Higher-priority focused scopes that are active in the current surface.',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: contextualScopes
                          .map((scope) => buildScopeTile(context, scope))
                          .toList(),
                    ),
                  ),
                if (globalScopes.isNotEmpty)
                  _HelpSection(
                    title: 'App-wide scopes',
                    subtitle:
                        'Shared shell bindings that remain available outside focused feature surfaces.',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: globalScopes
                          .map((scope) => buildScopeTile(context, scope))
                          .toList(),
                    ),
                  ),
                _HelpSection(
                  title: 'Resolved bindings',
                  subtitle:
                      'The currently effective binding for each configurable shortcut definition.',
                  child: Wrap(
                    spacing: spacing.sm,
                    runSpacing: spacing.sm,
                    children: resolvedBindings.entries
                        .map(
                          (entry) => _HelpToken(
                            label:
                                '${ShortcutCatalog.find(entry.key)?.label ?? entry.key} - ${entry.value.toConfigString()}',
                            icon: Icons.keyboard_command_key,
                          ),
                        )
                        .toList(),
                  ),
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
