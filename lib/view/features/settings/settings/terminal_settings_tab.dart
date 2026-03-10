import 'package:flutter/material.dart';

import 'package:cwatch/controller/controllers/settings_controller.dart';
import 'package:cwatch/model/models/app_settings.dart';
import 'package:cwatch/model/shared/shortcuts/shortcut_definition.dart';
import 'package:cwatch/model/shared/theme/app_theme.dart';
import 'settings_section.dart';
import 'shortcuts_settings_tab.dart';
import 'terminal_settings_controls.dart';

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
  final SettingsController settingsController;
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
    final spacing = context.appTheme.spacing;
    return ListView(
      padding: spacing.inset(horizontal: 1.5, vertical: 1),
      children: [
        SettingsSection(
          title: 'Appearance',
          description:
              'Choose the mono Nerd Font, sizing, spacing, and color theme used by the in-app terminal.',
          child: TerminalSettingsControls(
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
