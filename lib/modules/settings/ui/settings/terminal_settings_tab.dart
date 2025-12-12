import 'package:flutter/material.dart';

import 'package:cwatch/models/app_settings.dart';
import 'package:cwatch/services/settings/app_settings_controller.dart';
import 'package:cwatch/shared/shortcuts/shortcut_definition.dart';
import 'shortcuts_settings_tab.dart';
import 'terminal_settings_section.dart';

class TerminalSettingsTab extends StatelessWidget {
  const TerminalSettingsTab({
    super.key,
    required this.settings,
    required this.settingsController,
    required this.fontFamily,
    required this.fontSize,
    required this.lineHeight,
    required this.paddingX,
    required this.paddingY,
    required this.darkTheme,
    required this.lightTheme,
    required this.onFontFamilyChanged,
    required this.onFontSizeChanged,
    required this.onLineHeightChanged,
    required this.onPaddingXChanged,
    required this.onPaddingYChanged,
    required this.onDarkThemeChanged,
    required this.onLightThemeChanged,
  });

  final AppSettings settings;
  final AppSettingsController settingsController;
  final String? fontFamily;
  final double fontSize;
  final double lineHeight;
  final double paddingX;
  final double paddingY;
  final String darkTheme;
  final String lightTheme;
  final ValueChanged<String> onFontFamilyChanged;
  final ValueChanged<double> onFontSizeChanged;
  final ValueChanged<double> onLineHeightChanged;
  final ValueChanged<double> onPaddingXChanged;
  final ValueChanged<double> onPaddingYChanged;
  final ValueChanged<String> onDarkThemeChanged;
  final ValueChanged<String> onLightThemeChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      children: [
        TerminalSettingsSection(
          fontFamily: fontFamily,
          fontSize: fontSize,
          lineHeight: lineHeight,
          paddingX: paddingX,
          paddingY: paddingY,
          darkTheme: darkTheme,
          lightTheme: lightTheme,
          onFontFamilyChanged: onFontFamilyChanged,
          onFontSizeChanged: onFontSizeChanged,
          onLineHeightChanged: onLineHeightChanged,
          onPaddingXChanged: onPaddingXChanged,
          onPaddingYChanged: onPaddingYChanged,
          onDarkThemeChanged: onDarkThemeChanged,
          onLightThemeChanged: onLightThemeChanged,
        ),
        ShortcutCategorySection(
          category: ShortcutCategory.terminal,
          controller: settingsController,
          settings: settings,
          titleOverride: 'Shortcuts',
          descriptionOverride:
              'Keyboard shortcuts for copy/paste, scrollback, and zoom.',
        ),
      ],
    );
  }
}
