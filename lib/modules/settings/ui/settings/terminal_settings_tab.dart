import 'package:flutter/material.dart';

import 'terminal_settings_section.dart';

class TerminalSettingsTab extends StatelessWidget {
  const TerminalSettingsTab({
    super.key,
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
      ],
    );
  }
}
