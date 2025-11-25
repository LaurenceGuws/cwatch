import 'package:flutter/material.dart';

import 'settings_section.dart';
import 'editor_settings_section.dart' show kStyleThemes;

class TerminalSettingsSection extends StatefulWidget {
  const TerminalSettingsSection({
    super.key,
    required this.fontFamily,
    required this.fontSize,
    required this.lineHeight,
    required this.darkTheme,
    required this.lightTheme,
    required this.onFontFamilyChanged,
    required this.onFontSizeChanged,
    required this.onLineHeightChanged,
    required this.onDarkThemeChanged,
    required this.onLightThemeChanged,
  });

  final String? fontFamily;
  final double fontSize;
  final double lineHeight;
  final String darkTheme;
  final String lightTheme;
  final ValueChanged<String> onFontFamilyChanged;
  final ValueChanged<double> onFontSizeChanged;
  final ValueChanged<double> onLineHeightChanged;
  final ValueChanged<String> onDarkThemeChanged;
  final ValueChanged<String> onLightThemeChanged;

  @override
  State<TerminalSettingsSection> createState() =>
      _TerminalSettingsSectionState();
}

class _TerminalSettingsSectionState extends State<TerminalSettingsSection> {
  late final TextEditingController _fontController;

  @override
  void initState() {
    super.initState();
    _fontController = TextEditingController(text: widget.fontFamily ?? '');
  }

  @override
  void didUpdateWidget(covariant TerminalSettingsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fontFamily != widget.fontFamily &&
        _fontController.text != (widget.fontFamily ?? '')) {
      _fontController.text = widget.fontFamily ?? '';
    }
  }

  @override
  void dispose() {
    _fontController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SettingsSection(
      title: 'Terminal',
      description:
          'Choose the mono Nerd Font, sizing, and color theme used by the in-app terminal.',
      child: Column(
        children: [
          TextFormField(
            controller: _fontController,
            decoration: const InputDecoration(
              labelText: 'Font family',
              hintText: 'JetBrainsMono Nerd Font',
            ),
            onChanged: widget.onFontFamilyChanged,
          ),
          const SizedBox(height: 12),
          _SliderRow(
            label: 'Font size',
            valueLabel: widget.fontSize.toStringAsFixed(1),
            child: Slider(
              value: widget.fontSize.clamp(8, 24).toDouble(),
              min: 8,
              max: 24,
              divisions: 16,
              label: widget.fontSize.toStringAsFixed(1),
              onChanged: widget.onFontSizeChanged,
            ),
          ),
          _SliderRow(
            label: 'Line height',
            valueLabel: widget.lineHeight.toStringAsFixed(2),
            child: Slider(
              value: widget.lineHeight.clamp(0.9, 1.6).toDouble(),
              min: 0.9,
              max: 1.6,
              divisions: 14,
              label: widget.lineHeight.toStringAsFixed(2),
              onChanged: widget.onLineHeightChanged,
            ),
          ),
          const SizedBox(height: 12),
          _ThemePickerRow(
            label: 'Light theme',
            value: widget.lightTheme,
            onChanged: widget.onLightThemeChanged,
          ),
          const SizedBox(height: 8),
          _ThemePickerRow(
            label: 'Dark theme',
            value: widget.darkTheme,
            onChanged: widget.onDarkThemeChanged,
          ),
        ],
      ),
    );
  }
}

class _ThemePickerRow extends StatefulWidget {
  const _ThemePickerRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_ThemePickerRow> createState() => _ThemePickerRowState();
}

class _ThemePickerRowState extends State<_ThemePickerRow> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _ThemePickerRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && _controller.text != widget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = kStyleThemes.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    if (!items.any((e) => e.key == widget.value)) {
      items.add(MapEntry(widget.value, widget.value));
    }
    return DropdownButtonFormField<String>(
      initialValue: widget.value,
      decoration: InputDecoration(labelText: widget.label),
      items: items
          .map(
            (entry) =>
                DropdownMenuItem(value: entry.key, child: Text(entry.value)),
          )
          .toList(),
      onChanged: (value) {
        if (value == null) return;
        _controller.text = value;
        widget.onChanged(value);
      },
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.valueLabel,
    required this.child,
  });

  final String label;
  final String valueLabel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
            Text(valueLabel),
          ],
        ),
        child,
      ],
    );
  }
}
