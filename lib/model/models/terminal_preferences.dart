import 'package:cwatch/model/config/config_metadata_annotations.dart';

@ConfigGroup(
  key: 'terminalPreferences',
  label: 'Terminal Preferences',
  description: 'Shared terminal theme, spacing, and typography preferences.',
  order: 30,
)
class TerminalPreferences {
  const TerminalPreferences({
    this.fontFamily = 'JetBrainsMono Nerd Font',
    this.fontSize = 14,
    this.lineHeight = 1.15,
    this.paddingX = 8,
    this.paddingY = 10,
    this.themeDark = 'dracula',
    this.themeLight = 'solarized-light',
  });

  @ConfigField(
    key: 'fontFamily',
    label: 'Font Family',
    description: 'Preferred terminal font family.',
    kind: ConfigValueKind.string,
    defaultValueDoc: 'JetBrainsMono Nerd Font',
  )
  final String? fontFamily;
  @ConfigField(
    key: 'fontSize',
    label: 'Font Size',
    description: 'Preferred terminal font size.',
    kind: ConfigValueKind.doubleValue,
    unit: 'pt',
    defaultValueDoc: '14',
  )
  final double fontSize;
  @ConfigField(
    key: 'lineHeight',
    label: 'Line Height',
    description: 'Preferred terminal line height multiplier.',
    kind: ConfigValueKind.doubleValue,
    defaultValueDoc: '1.15',
  )
  final double lineHeight;
  @ConfigField(
    key: 'paddingX',
    label: 'Horizontal Padding',
    description: 'Horizontal terminal padding.',
    kind: ConfigValueKind.doubleValue,
    unit: 'px',
    defaultValueDoc: '8',
  )
  final double paddingX;
  @ConfigField(
    key: 'paddingY',
    label: 'Vertical Padding',
    description: 'Vertical terminal padding.',
    kind: ConfigValueKind.doubleValue,
    unit: 'px',
    defaultValueDoc: '10',
  )
  final double paddingY;
  @ConfigField(
    key: 'themeDark',
    label: 'Dark Theme',
    description: 'Preferred terminal theme in dark mode.',
    kind: ConfigValueKind.string,
    defaultValueDoc: 'dracula',
  )
  final String themeDark;
  @ConfigField(
    key: 'themeLight',
    label: 'Light Theme',
    description: 'Preferred terminal theme in light mode.',
    kind: ConfigValueKind.string,
    defaultValueDoc: 'solarized-light',
  )
  final String themeLight;

  TerminalPreferences copyWith({
    String? fontFamily,
    double? fontSize,
    double? lineHeight,
    double? paddingX,
    double? paddingY,
    String? themeDark,
    String? themeLight,
  }) {
    return TerminalPreferences(
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      paddingX: paddingX ?? this.paddingX,
      paddingY: paddingY ?? this.paddingY,
      themeDark: themeDark ?? this.themeDark,
      themeLight: themeLight ?? this.themeLight,
    );
  }
}
