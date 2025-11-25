import 'package:flutter/material.dart';

import 'settings_section.dart';

class EditorSettingsSection extends StatefulWidget {
  const EditorSettingsSection({
    super.key,
    required this.fontFamily,
    required this.fontSize,
    required this.lineHeight,
    required this.onFontFamilyChanged,
    required this.onFontSizeChanged,
    required this.onLineHeightChanged,
  });

  final String? fontFamily;
  final double fontSize;
  final double lineHeight;
  final ValueChanged<String> onFontFamilyChanged;
  final ValueChanged<double> onFontSizeChanged;
  final ValueChanged<double> onLineHeightChanged;

  @override
  State<EditorSettingsSection> createState() => _EditorSettingsSectionState();
}

class _EditorSettingsSectionState extends State<EditorSettingsSection> {
  late final TextEditingController _fontController;

  @override
  void initState() {
    super.initState();
    _fontController = TextEditingController(text: widget.fontFamily ?? '');
  }

  @override
  void didUpdateWidget(covariant EditorSettingsSection oldWidget) {
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
      title: 'Text Editor',
      description:
          'Configure the mono font and spacing used in the remote file editor.',
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
              value: widget.lineHeight.clamp(1.0, 2.0).toDouble(),
              min: 1.0,
              max: 2.0,
              divisions: 20,
              label: widget.lineHeight.toStringAsFixed(2),
              onChanged: widget.onLineHeightChanged,
            ),
          ),
        ],
      ),
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
