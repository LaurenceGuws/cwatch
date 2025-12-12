import 'package:flutter/material.dart';

import 'package:cwatch/models/app_settings.dart';
import 'package:cwatch/services/settings/app_settings_controller.dart';
import 'package:cwatch/shared/shortcuts/shortcut_definition.dart';
import 'shortcuts_settings_tab.dart';
import 'editor_settings_section.dart';

class EditorSettingsTab extends StatelessWidget {
  const EditorSettingsTab({
    super.key,
    required this.settings,
    required this.settingsController,
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

  final AppSettings settings;
  final AppSettingsController settingsController;
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
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      children: [
        EditorSettingsSection(
          fontFamily: fontFamily,
          fontSize: fontSize,
          lineHeight: lineHeight,
          onFontFamilyChanged: onFontFamilyChanged,
          onFontSizeChanged: onFontSizeChanged,
          onLineHeightChanged: onLineHeightChanged,
          lightTheme: lightTheme,
          darkTheme: darkTheme,
          onLightThemeChanged: onLightThemeChanged,
          onDarkThemeChanged: onDarkThemeChanged,
        ),
        ShortcutCategorySection(
          category: ShortcutCategory.editor,
          controller: settingsController,
          settings: settings,
          titleOverride: 'Shortcuts',
          descriptionOverride:
              'Keyboard shortcuts for navigation and editor commands.',
        ),
      ],
    );
  }
}
