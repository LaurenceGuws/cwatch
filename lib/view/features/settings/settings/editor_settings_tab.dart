import 'package:flutter/material.dart';

import 'package:cwatch/controller/controllers/settings_controller.dart';
import 'package:cwatch/model/models/app_settings.dart';
import 'package:cwatch/model/shared/shortcuts/shortcut_definition.dart';
import 'package:cwatch/model/shared/theme/app_theme.dart';
import 'editor_settings_controls.dart';
import 'settings_section.dart';
import 'shortcuts_settings_tab.dart';

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
  final SettingsController settingsController;
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
    final spacing = context.appTheme.spacing;
    return ListView(
      padding: spacing.inset(horizontal: 1.5, vertical: 1),
      children: [
        SettingsSection(
          title: 'Appearance',
          description:
              'Configure mono font, spacing, and themes used in the remote file editor and diffs.',
          child: EditorSettingsControls(
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
