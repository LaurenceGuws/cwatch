import 'package:flutter/material.dart';

import 'settings_section.dart';
import 'editor_settings_controls.dart';

class EditorSettingsSection extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return SettingsSection(
      title: 'Appearance',
      description:
          'Configure mono font, spacing, and themes used in the remote file editor and diffs.',
      child: EditorSettingsControls(
        fontFamily: fontFamily,
        fontSize: fontSize,
        lineHeight: lineHeight,
        lightTheme: lightTheme,
        darkTheme: darkTheme,
        onFontFamilyChanged: onFontFamilyChanged,
        onFontSizeChanged: onFontSizeChanged,
        onLineHeightChanged: onLineHeightChanged,
        onLightThemeChanged: onLightThemeChanged,
        onDarkThemeChanged: onDarkThemeChanged,
      ),
    );
  }
}
