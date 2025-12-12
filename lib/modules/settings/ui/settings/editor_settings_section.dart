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
    required this.lightTheme,
    required this.darkTheme,
    required this.onLightThemeChanged,
    required this.onDarkThemeChanged,
  });

  final String? fontFamily;
  final double fontSize;
  final double lineHeight;
  final ValueChanged<String> onFontFamilyChanged;
  final ValueChanged<double> onFontSizeChanged;
  final ValueChanged<double> onLineHeightChanged;
  final String? lightTheme;
  final String? darkTheme;
  final ValueChanged<String> onLightThemeChanged;
  final ValueChanged<String> onDarkThemeChanged;

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
      title: 'Appearance',
      description:
          'Configure mono font, spacing, and themes used in the remote file editor and diffs.',
      child: Column(
        children: [
          const _GroupLabel('Typography'),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Applies to the built-in code editor and diff viewers.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 12),
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
          const SizedBox(height: 12),
          const _GroupLabel('Highlighting'),
          _ThemePickerRow(
            label: 'Light theme',
            value: widget.lightTheme ?? 'atom-one-light',
            onChanged: widget.onLightThemeChanged,
          ),
          const SizedBox(height: 12),
          _ThemePickerRow(
            label: 'Dark theme',
            value: widget.darkTheme ?? 'atom-one-dark',
            onChanged: widget.onDarkThemeChanged,
          ),
        ],
      ),
    );
  }
}

// Shared list of style themes for app, terminal, and editor.
const Map<String, String> kStyleThemes = {
  'a11y-dark': 'A11y Dark',
  'a11y-light': 'A11y Light',
  'agate': 'Agate',
  'an-old-hope': 'An Old Hope',
  'androidstudio': 'Android Studio',
  'arduino-light': 'Arduino Light',
  'arta': 'Arta',
  'ascetic': 'Ascetic',
  'atelier-cave-dark': 'Atelier Cave Dark',
  'atelier-cave-light': 'Atelier Cave Light',
  'atelier-dune-dark': 'Atelier Dune Dark',
  'atelier-dune-light': 'Atelier Dune Light',
  'atelier-estuary-dark': 'Atelier Estuary Dark',
  'atelier-estuary-light': 'Atelier Estuary Light',
  'atelier-forest-dark': 'Atelier Forest Dark',
  'atelier-forest-light': 'Atelier Forest Light',
  'atelier-heath-dark': 'Atelier Heath Dark',
  'atelier-heath-light': 'Atelier Heath Light',
  'atelier-lakeside-dark': 'Atelier Lakeside Dark',
  'atelier-lakeside-light': 'Atelier Lakeside Light',
  'atelier-plateau-dark': 'Atelier Plateau Dark',
  'atelier-plateau-light': 'Atelier Plateau Light',
  'atelier-savanna-dark': 'Atelier Savanna Dark',
  'atelier-savanna-light': 'Atelier Savanna Light',
  'atelier-seaside-dark': 'Atelier Seaside Dark',
  'atelier-seaside-light': 'Atelier Seaside Light',
  'atelier-sulphurpool-dark': 'Atelier Sulphurpool Dark',
  'atelier-sulphurpool-light': 'Atelier Sulphurpool Light',
  'atom-one-dark': 'Atom One Dark',
  'atom-one-dark-reasonable': 'Atom One Dark Reasonable',
  'atom-one-light': 'Atom One Light',
  'brown-paper': 'Brown Paper',
  'codepen-embed': 'CodePen Embed',
  'color-brewer': 'Color Brewer',
  'darcula': 'Darcula',
  'dark': 'Dark',
  'default': 'Default',
  'docco': 'Docco',
  'dracula': 'Dracula',
  'far': 'Far',
  'foundation': 'Foundation',
  'github': 'GitHub',
  'github-gist': 'GitHub Gist',
  'gml': 'GML',
  'googlecode': 'Google Code',
  'gradient-dark': 'Gradient Dark',
  'grayscale': 'Grayscale',
  'gruvbox-dark': 'Gruvbox Dark',
  'gruvbox-light': 'Gruvbox Light',
  'hopscotch': 'Hopscotch',
  'hybrid': 'Hybrid',
  'idea': 'IDEA',
  'ir-black': 'IR Black',
  'isbl-editor-dark': 'ISBL Editor Dark',
  'isbl-editor-light': 'ISBL Editor Light',
  'kimbie.dark': 'Kimbie Dark',
  'kimbie.light': 'Kimbie Light',
  'lightfair': 'Lightfair',
  'magula': 'Magula',
  'mono-blue': 'Mono Blue',
  'monokai': 'Monokai',
  'monokai-sublime': 'Monokai Sublime',
  'night-owl': 'Night Owl',
  'nord': 'Nord',
  'obsidian': 'Obsidian',
  'ocean': 'Ocean',
  'paraiso-dark': 'Paraiso Dark',
  'paraiso-light': 'Paraiso Light',
  'pojoaque': 'Pojoaque',
  'purebasic': 'PureBasic',
  'qtcreator_dark': 'Qt Creator Dark',
  'qtcreator_light': 'Qt Creator Light',
  'railscasts': 'RailsCasts',
  'rainbow': 'Rainbow',
  'routeros': 'RouterOS',
  'school-book': 'School Book',
  'shades-of-purple': 'Shades of Purple',
  'solarized-dark': 'Solarized Dark',
  'solarized-light': 'Solarized Light',
  'sunburst': 'Sunburst',
  'tomorrow': 'Tomorrow',
  'tomorrow-night': 'Tomorrow Night',
  'tomorrow-night-blue': 'Tomorrow Night Blue',
  'tomorrow-night-bright': 'Tomorrow Night Bright',
  'tomorrow-night-eighties': 'Tomorrow Night Eighties',
  'vs': 'VS',
  'vs2015': 'VS 2015',
  'xcode': 'Xcode',
  'xt256': 'XT256',
  'zenburn': 'Zenburn',
};

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

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
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

  static const Map<String, String> _themeOptions = kStyleThemes;

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
    final items = _ThemePickerRow._themeOptions.entries.toList()
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
