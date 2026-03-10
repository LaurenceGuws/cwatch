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

  final String? fontFamily;
  final double fontSize;
  final double lineHeight;
  final double paddingX;
  final double paddingY;
  final String themeDark;
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
