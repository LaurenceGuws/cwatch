class EditorPreferences {
  const EditorPreferences({
    this.themeLight,
    this.themeDark,
    this.fontFamily,
    this.fontSize = 14,
    this.lineHeight = 1.35,
  });

  final String? themeLight;
  final String? themeDark;
  final String? fontFamily;
  final double fontSize;
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
