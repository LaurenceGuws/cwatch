import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:cwatch/models/app_settings.dart';
import 'package:cwatch/services/settings/app_settings_controller.dart';
import 'package:cwatch/shared/shortcuts/shortcut_binding.dart';
import 'package:cwatch/shared/shortcuts/shortcut_definition.dart';
import 'package:cwatch/shared/theme/app_theme.dart';
import 'package:cwatch/shared/widgets/form_spacer.dart';
import 'settings_section.dart';

class ShortcutsSettingsTab extends StatelessWidget {
  const ShortcutsSettingsTab({
    super.key,
    required this.controller,
    required this.settings,
  });

  final AppSettingsController controller;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appTheme.spacing;
    return ListView(
      padding: spacing.inset(horizontal: 1.5, vertical: 1),
      children: [
        ...ShortcutCategory.values.map(
          (category) => ShortcutCategorySection(
            category: category,
            controller: controller,
            settings: settings,
          ),
        ),
      ],
    );
  }
}

class ShortcutCategorySection extends StatelessWidget {
  const ShortcutCategorySection({
    required this.category,
    required this.controller,
    required this.settings,
    this.titleOverride,
    this.descriptionOverride,
    super.key,
  });

  final ShortcutCategory category;
  final AppSettingsController controller;
  final AppSettings settings;
  final String? titleOverride;
  final String? descriptionOverride;

  String get _title {
    if (titleOverride != null && titleOverride!.isNotEmpty) {
      return titleOverride!;
    }
    switch (category) {
      case ShortcutCategory.global:
        return 'Global';
      case ShortcutCategory.terminal:
        return 'Terminal';
      case ShortcutCategory.tabs:
        return 'Tabs';
      case ShortcutCategory.editor:
        return 'Editor';
      case ShortcutCategory.docker:
        return 'Docker';
      case ShortcutCategory.grid:
        return 'Grid';
    }
  }

  String get _description {
    if (descriptionOverride != null && descriptionOverride!.isNotEmpty) {
      return descriptionOverride!;
    }
    switch (category) {
      case ShortcutCategory.global:
        return 'App-wide shortcuts.';
      case ShortcutCategory.terminal:
        return 'Terminal interactions and scrolling.';
      case ShortcutCategory.tabs:
        return 'Tab navigation and management.';
      case ShortcutCategory.editor:
        return 'Editor actions and navigation.';
      case ShortcutCategory.docker:
        return 'Docker and container shortcuts.';
      case ShortcutCategory.grid:
        return 'Spreadsheet-style navigation and selection.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final definitions = ShortcutCatalog.byCategory(category).toList();
    return SettingsSection(
      title: _title,
      description: _description,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Configure key bindings. Leave a field empty to use the default.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const FormSpacer(),
          if (definitions.isEmpty)
            Text(
              'No shortcuts available for this section yet.',
              style: Theme.of(context).textTheme.bodySmall,
            )
          else
            ...definitions.map(
              (definition) => _ShortcutRow(
                definition: definition,
                controller: controller,
                settings: settings,
              ),
            ),
        ],
      ),
    );
  }
}

class _ShortcutRow extends StatefulWidget {
  const _ShortcutRow({
    required this.definition,
    required this.controller,
    required this.settings,
  });

  final ShortcutDefinition definition;
  final AppSettingsController controller;
  final AppSettings settings;

  @override
  State<_ShortcutRow> createState() => _ShortcutRowState();
}

class _ShortcutRowState extends State<_ShortcutRow> {
  late final TextEditingController _textController;
  late final FocusNode _focusNode;
  String? _error;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: _currentValue);
    _focusNode = FocusNode();
    _focusNode.onKeyEvent = _handleKeyCapture;
  }

  @override
  void didUpdateWidget(covariant _ShortcutRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings.shortcutBindings !=
        widget.settings.shortcutBindings) {
      _textController.text = _currentValue;
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _textController.dispose();
    super.dispose();
  }

  String get _currentValue =>
      widget.settings.shortcutBindings[widget.definition.id] ??
      widget.definition.defaultBinding;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appTheme.spacing;
    final helpStyle = Theme.of(context).textTheme.bodySmall;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.definition.label,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              TextButton(
                onPressed: _resetToDefault,
                child: const Text('Reset'),
              ),
            ],
          ),
          Text(widget.definition.description, style: helpStyle),
          SizedBox(height: spacing.sm),
          TextField(
            controller: _textController,
            focusNode: _focusNode,
            decoration: InputDecoration(
              hintText: 'ctrl+shift+c',
              errorText: _error,
              isDense: true,
            ),
            onChanged: _handleChanged,
          ),
        ],
      ),
    );
  }

  void _handleChanged(String value) {
    final parsed = ShortcutBinding.tryParse(value);
    if (value.trim().isEmpty) {
      _setError(null);
      _updateBinding(null);
      return;
    }
    if (parsed == null) {
      _setError('Enter a valid binding (e.g., ctrl+shift+c)');
      return;
    }
    final normalized = parsed.toConfigString();
    if (_textController.text != normalized) {
      _textController.value = TextEditingValue(
        text: normalized,
        selection: TextSelection.collapsed(offset: normalized.length),
      );
    }
    _setError(null);
    _updateBinding(normalized);
  }

  KeyEventResult _handleKeyCapture(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final binding = ShortcutBinding.fromKeyEvent(event);
    if (binding == null) {
      return KeyEventResult.ignored;
    }
    final normalized = binding.toConfigString();
    _textController.value = TextEditingValue(
      text: normalized,
      selection: TextSelection.collapsed(offset: normalized.length),
    );
    _setError(null);
    _updateBinding(normalized);
    return KeyEventResult.handled;
  }

  void _resetToDefault() {
    final normalized = widget.definition.defaultBinding;
    _textController.value = TextEditingValue(
      text: normalized,
      selection: TextSelection.collapsed(offset: normalized.length),
    );
    _setError(null);
    _updateBinding(normalized);
  }

  void _updateBinding(String? value) {
    widget.controller.update((current) {
      final updated = Map<String, String>.from(current.shortcutBindings);
      if (value == null || value.trim().isEmpty) {
        updated.remove(widget.definition.id);
      } else {
        updated[widget.definition.id] = value.trim();
      }
      return current.copyWith(shortcutBindings: updated);
    });
  }

  void _setError(String? message) {
    if (_error == message) return;
    setState(() => _error = message);
  }
}
