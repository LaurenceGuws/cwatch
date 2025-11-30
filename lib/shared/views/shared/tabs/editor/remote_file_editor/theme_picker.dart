import 'package:flutter/material.dart';

import '../../../../../widgets/style_picker_dialog.dart';
import 'editor_theme_utils.dart';

Future<void> showEditorThemeDialog({
  required BuildContext context,
  required Brightness brightness,
  required String? savedTheme,
  required void Function(String themeKey) onSelect,
  required void Function(String themeKey) onPreview,
}) async {
  final themes = editorThemeOptions();
  final defaultTheme = brightness == Brightness.dark ? 'dracula' : 'color-brewer';
  final initialKey = savedTheme ?? defaultTheme;
  final options =
      themes.entries.map((e) => StyleOption(key: e.key, label: e.value)).toList();

  final chosen = await showStylePickerDialog(
    context: context,
    title: 'Select editor theme',
    options: options,
    selectedKey: initialKey,
    onPreview: onPreview,
  );

  if (chosen == null) {
    onSelect(savedTheme ?? defaultTheme);
  } else {
    onSelect(chosen);
  }
}
