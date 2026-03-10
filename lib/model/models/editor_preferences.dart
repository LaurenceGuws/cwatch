import 'package:cwatch/model/config/config_metadata_annotations.dart';

@ConfigGroup(
  key: 'editorPreferences',
  label: 'Editor Preferences',
  description: 'Shared editor theme and typography preferences.',
  order: 20,
)
class EditorPreferences {
  const EditorPreferences({
    this.themeLight,
    this.themeDark,
    this.fontFamily,
    this.fontSize = 14,
    this.lineHeight = 1.35,
  });

  @ConfigField(
    key: 'themeLight',
    label: 'Light Theme',
    description: 'Preferred editor theme when the app is in light mode.',
    kind: ConfigValueKind.string,
  )
  final String? themeLight;
  @ConfigField(
    key: 'themeDark',
    label: 'Dark Theme',
    description: 'Preferred editor theme when the app is in dark mode.',
    kind: ConfigValueKind.string,
  )
  final String? themeDark;
  @ConfigField(
    key: 'fontFamily',
    label: 'Font Family',
    description: 'Preferred editor font family.',
    kind: ConfigValueKind.string,
  )
  final String? fontFamily;
  @ConfigField(
    key: 'fontSize',
    label: 'Font Size',
    description: 'Preferred editor font size.',
    kind: ConfigValueKind.doubleValue,
    unit: 'pt',
    defaultValueDoc: '14',
  )
  final double fontSize;
  @ConfigField(
    key: 'lineHeight',
    label: 'Line Height',
    description: 'Preferred editor line height multiplier.',
    kind: ConfigValueKind.doubleValue,
    defaultValueDoc: '1.35',
  )
  final double lineHeight;

  EditorPreferences copyWith({
    String? themeLight,
    String? themeDark,
    String? fontFamily,
    double? fontSize,
    double? lineHeight,
  }) {
    return EditorPreferences(
      themeLight: themeLight ?? this.themeLight,
      themeDark: themeDark ?? this.themeDark,
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
    );
  }
}
