part of app_theme;

class AppListTokens {
  const AppListTokens({
    required this.hoverBackground,
    required this.hoverBorder,
    required this.focusOutline,
    required this.selectedBackground,
    required this.selectedForeground,
    required this.unselectedForeground,
    required this.stripeEvenBackground,
    required this.stripeOddBackground,
  });

  final Color hoverBackground;
  final Color hoverBorder;
  final Color focusOutline;
  final Color selectedBackground;
  final Color selectedForeground;
  final Color unselectedForeground;
  final Color stripeEvenBackground;
  final Color stripeOddBackground;

  factory AppListTokens.fromScheme(ColorScheme scheme) {
    return AppListTokens(
      hoverBackground: scheme.surfaceContainerHighest,
      hoverBorder: scheme.outlineVariant,
      focusOutline: scheme.primary,
      selectedBackground: scheme.primary.withValues(alpha: 0.08),
      selectedForeground: scheme.primary,
      unselectedForeground: scheme.onSurface,
      stripeEvenBackground: scheme.surface,
      stripeOddBackground: scheme.surfaceContainerHigh,
    );
  }

  static AppListTokens lerp(AppListTokens a, AppListTokens b, double t) {
    return AppListTokens(
      hoverBackground:
          Color.lerp(a.hoverBackground, b.hoverBackground, t) ??
          a.hoverBackground,
      hoverBorder:
          Color.lerp(a.hoverBorder, b.hoverBorder, t) ?? a.hoverBorder,
      focusOutline:
          Color.lerp(a.focusOutline, b.focusOutline, t) ?? a.focusOutline,
      selectedBackground:
          Color.lerp(a.selectedBackground, b.selectedBackground, t) ??
          a.selectedBackground,
      selectedForeground:
          Color.lerp(a.selectedForeground, b.selectedForeground, t) ??
          a.selectedForeground,
      unselectedForeground:
          Color.lerp(a.unselectedForeground, b.unselectedForeground, t) ??
          a.unselectedForeground,
      stripeEvenBackground:
          Color.lerp(a.stripeEvenBackground, b.stripeEvenBackground, t) ??
          a.stripeEvenBackground,
      stripeOddBackground:
          Color.lerp(a.stripeOddBackground, b.stripeOddBackground, t) ??
          a.stripeOddBackground,
    );
  }
}

