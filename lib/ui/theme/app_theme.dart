import 'package:flutter/material.dart';

import 'nerd_fonts.dart';

/// Theme extension that exposes cascading styling primitives for the app.
class AppThemeTokens extends ThemeExtension<AppThemeTokens> {
  const AppThemeTokens({
    required this.spacing,
    required this.tabChip,
    required this.section,
    required this.typography,
  });

  final AppSpacing spacing;
  final AppTabChipTokens tabChip;
  final AppSectionTokens section;
  final AppTypographyTokens typography;

  factory AppThemeTokens.light(ColorScheme scheme) {
    final baseTheme = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      fontFamily: NerdFonts.family,
    );
    return AppThemeTokens(
      spacing: const AppSpacing(),
      tabChip: AppTabChipTokens.fromScheme(scheme),
      section: AppSectionTokens.fromScheme(scheme),
      typography: AppTypographyTokens.fromTextTheme(baseTheme.textTheme),
    );
  }

  factory AppThemeTokens.dark(ColorScheme scheme) {
    final baseTheme = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      fontFamily: NerdFonts.family,
    );
    return AppThemeTokens(
      spacing: const AppSpacing(),
      tabChip: AppTabChipTokens.fromScheme(scheme),
      section: AppSectionTokens.fromScheme(scheme),
      typography: AppTypographyTokens.fromTextTheme(baseTheme.textTheme),
    );
  }

  @override
  ThemeExtension<AppThemeTokens> copyWith({
    AppSpacing? spacing,
    AppTabChipTokens? tabChip,
    AppSectionTokens? section,
    AppTypographyTokens? typography,
  }) {
    return AppThemeTokens(
      spacing: spacing ?? this.spacing,
      tabChip: tabChip ?? this.tabChip,
      section: section ?? this.section,
      typography: typography ?? this.typography,
    );
  }

  @override
  ThemeExtension<AppThemeTokens> lerp(ThemeExtension<AppThemeTokens>? other, double t) {
    if (other is! AppThemeTokens) {
      return this;
    }
    return AppThemeTokens(
      spacing: spacing,
      tabChip: AppTabChipTokens.lerp(tabChip, other.tabChip, t),
      section: AppSectionTokens.lerp(section, other.section, t),
      typography: AppTypographyTokens.lerp(typography, other.typography, t),
    );
  }
}

class AppSpacing {
  const AppSpacing({this.base = 6});

  final double base;

  double get xs => base * 0.5;
  double get sm => base;
  double get md => base * 2;
  double get lg => base * 3;
  double get xl => base * 4;

  EdgeInsets inset({double horizontal = 1, double vertical = 1}) {
    return EdgeInsets.symmetric(horizontal: base * horizontal, vertical: base * vertical);
  }

  EdgeInsets all(double factor) => EdgeInsets.all(base * factor);
}

class AppTabChipTokens {
  const AppTabChipTokens({
    required this.selectedBackground,
    required this.unselectedBackground,
    required this.selectedForeground,
    required this.unselectedForeground,
    required this.selectedBorder,
    required this.unselectedBorder,
    required this.borderRadius,
    required this.horizontalPadding,
    required this.verticalPadding,
  });

  final Color selectedBackground;
  final Color unselectedBackground;
  final Color selectedForeground;
  final Color unselectedForeground;
  final Color selectedBorder;
  final Color unselectedBorder;
  final BorderRadius borderRadius;
  final double horizontalPadding;
  final double verticalPadding;

  factory AppTabChipTokens.fromScheme(ColorScheme scheme) {
    return AppTabChipTokens(
      selectedBackground: scheme.primaryContainer,
      unselectedBackground: Colors.transparent,
      selectedForeground: scheme.onPrimaryContainer,
      unselectedForeground: scheme.onSurfaceVariant,
      selectedBorder: scheme.primary,
      unselectedBorder: scheme.outlineVariant,
      borderRadius: BorderRadius.circular(8),
      horizontalPadding: 1.5,
      verticalPadding: 0.75,
    );
  }

  AppTabChipStyle style({required bool selected, required AppSpacing spacing}) {
    return AppTabChipStyle(
      background: selected ? selectedBackground : unselectedBackground,
      foreground: selected ? selectedForeground : unselectedForeground,
      borderColor: selected ? selectedBorder : unselectedBorder,
      padding: EdgeInsets.symmetric(
        horizontal: spacing.base * horizontalPadding,
        vertical: spacing.base * verticalPadding,
      ),
      borderRadius: borderRadius,
    );
  }

  static AppTabChipTokens lerp(AppTabChipTokens a, AppTabChipTokens b, double t) {
    return AppTabChipTokens(
      selectedBackground: Color.lerp(a.selectedBackground, b.selectedBackground, t) ?? a.selectedBackground,
      unselectedBackground: Color.lerp(a.unselectedBackground, b.unselectedBackground, t) ?? a.unselectedBackground,
      selectedForeground: Color.lerp(a.selectedForeground, b.selectedForeground, t) ?? a.selectedForeground,
      unselectedForeground: Color.lerp(a.unselectedForeground, b.unselectedForeground, t) ?? a.unselectedForeground,
      selectedBorder: Color.lerp(a.selectedBorder, b.selectedBorder, t) ?? a.selectedBorder,
      unselectedBorder: Color.lerp(a.unselectedBorder, b.unselectedBorder, t) ?? a.unselectedBorder,
      borderRadius: BorderRadius.lerp(a.borderRadius, b.borderRadius, t) ?? a.borderRadius,
      horizontalPadding: lerpDouble(a.horizontalPadding, b.horizontalPadding, t),
      verticalPadding: lerpDouble(a.verticalPadding, b.verticalPadding, t),
    );
  }
}

class AppTabChipStyle {
  const AppTabChipStyle({
    required this.background,
    required this.foreground,
    required this.borderColor,
    required this.padding,
    required this.borderRadius,
  });

  final Color background;
  final Color foreground;
  final Color borderColor;
  final EdgeInsets padding;
  final BorderRadius borderRadius;
}

class AppSectionTokens {
  const AppSectionTokens({
    required this.toolbarBackground,
    required this.divider,
    required this.surface,
  });

  final Color toolbarBackground;
  final Color divider;
  final AppSurfaceStyle surface;

  BorderRadius get cardRadius => surface.radius;

  factory AppSectionTokens.fromScheme(ColorScheme scheme) {
    return AppSectionTokens(
      toolbarBackground: scheme.surface,
      divider: scheme.outlineVariant,
      surface: AppSurfaceStyle(
        background: scheme.surfaceContainerHigh,
        borderColor: scheme.outlineVariant.withValues(alpha: 0.6),
        radius: BorderRadius.circular(10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        margin: EdgeInsets.zero,
        elevation: 0.5,
      ),
    );
  }

  static AppSectionTokens lerp(AppSectionTokens a, AppSectionTokens b, double t) {
    return AppSectionTokens(
      toolbarBackground: Color.lerp(a.toolbarBackground, b.toolbarBackground, t) ?? a.toolbarBackground,
      divider: Color.lerp(a.divider, b.divider, t) ?? a.divider,
      surface: AppSurfaceStyle.lerp(a.surface, b.surface, t),
    );
  }
}

class AppSurfaceStyle {
  const AppSurfaceStyle({
    required this.background,
    required this.borderColor,
    required this.radius,
    required this.padding,
    required this.margin,
    required this.elevation,
  });

  final Color background;
  final Color borderColor;
  final BorderRadius radius;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final double elevation;

  static AppSurfaceStyle lerp(AppSurfaceStyle a, AppSurfaceStyle b, double t) {
    return AppSurfaceStyle(
      background: Color.lerp(a.background, b.background, t) ?? a.background,
      borderColor: Color.lerp(a.borderColor, b.borderColor, t) ?? a.borderColor,
      radius: BorderRadius.lerp(a.radius, b.radius, t) ?? a.radius,
      padding: EdgeInsets.lerp(a.padding, b.padding, t) ?? a.padding,
      margin: EdgeInsets.lerp(a.margin, b.margin, t) ?? a.margin,
      elevation: lerpDouble(a.elevation, b.elevation, t),
    );
  }
}

class AppTypographyTokens {
  const AppTypographyTokens({
    required this.sectionTitle,
    required this.body,
    required this.caption,
    required this.code,
    required this.tabLabel,
  });

  final TextStyle sectionTitle;
  final TextStyle body;
  final TextStyle caption;
  final TextStyle code;
  final TextStyle tabLabel;

  factory AppTypographyTokens.fromTextTheme(TextTheme textTheme) {
    return AppTypographyTokens(
      sectionTitle: textTheme.titleLarge ?? const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
      body: textTheme.bodyMedium ?? const TextStyle(fontSize: 14),
      caption: textTheme.bodySmall ?? const TextStyle(fontSize: 12),
      code: (textTheme.bodySmall ?? const TextStyle()).copyWith(fontFamily: 'monospace'),
      tabLabel: textTheme.labelLarge ?? const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    );
  }

  static AppTypographyTokens lerp(AppTypographyTokens a, AppTypographyTokens b, double t) {
    return AppTypographyTokens(
      sectionTitle: TextStyle.lerp(a.sectionTitle, b.sectionTitle, t) ?? a.sectionTitle,
      body: TextStyle.lerp(a.body, b.body, t) ?? a.body,
      caption: TextStyle.lerp(a.caption, b.caption, t) ?? a.caption,
      code: TextStyle.lerp(a.code, b.code, t) ?? a.code,
      tabLabel: TextStyle.lerp(a.tabLabel, b.tabLabel, t) ?? a.tabLabel,
    );
  }
}

extension BuildContextAppTheme on BuildContext {
  AppThemeTokens get appTheme => Theme.of(this).extension<AppThemeTokens>()!;
}

double lerpDouble(double a, double b, double t) => a + (b - a) * t;
