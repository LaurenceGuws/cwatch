import 'package:flutter/material.dart';

import 'nerd_fonts.dart';

part 'tokens/app_list_tokens.dart';
part 'tokens/app_icons_tokens.dart';
part 'tokens/app_dimensions_tokens.dart';
part 'tokens/app_docker_tokens.dart';
part 'tokens/app_tab_chip_tokens.dart';
part 'tokens/app_section_tokens.dart';

/// Theme extension that exposes cascading styling primitives for the app.
class AppThemeTokens extends ThemeExtension<AppThemeTokens> {
  const AppThemeTokens({
    required this.spacing,
    required this.tabChip,
    required this.list,
    required this.section,
    required this.typography,
    required this.icons,
    required this.iconSizes,
    required this.dimensions,
    required this.docker,
    required this.distroColors,
  });

  final AppSpacing spacing;
  final AppTabChipTokens tabChip;
  final AppListTokens list;
  final AppSectionTokens section;
  final AppTypographyTokens typography;
  final AppIcons icons;
  final AppIconsTokens iconSizes;
  final AppDimensionsTokens dimensions;
  final AppDockerTokens docker;
  final DistroColors distroColors;

  factory AppThemeTokens.light(
    ColorScheme scheme, {
    String? fontFamily,
    BorderRadius? surfaceRadius,
    double? spacingBase,
    double zoomFactor = 1.0,
  }) {
    final baseTheme = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      fontFamily: fontFamily,
    );
    final radius = surfaceRadius ?? BorderRadius.circular(2 * zoomFactor);
    return AppThemeTokens(
      spacing: AppSpacing(base: spacingBase ?? 4, zoomFactor: zoomFactor),
      tabChip: AppTabChipTokens.fromScheme(scheme, zoomFactor: zoomFactor),
      list: AppListTokens.fromScheme(scheme),
      section: AppSectionTokens.fromScheme(
        scheme,
        surfaceRadius: radius,
        zoomFactor: zoomFactor,
      ),
      typography: AppTypographyTokens.fromTextTheme(
        baseTheme.textTheme,
        zoomFactor: zoomFactor,
      ),
      icons: AppIcons.nerd(),
      iconSizes: AppIconsTokens(zoomFactor: zoomFactor),
      dimensions: AppDimensionsTokens(zoomFactor: zoomFactor),
      docker: AppDockerTokens.fromScheme(scheme),
      distroColors: DistroColors.standard(),
    );
  }

  factory AppThemeTokens.dark(
    ColorScheme scheme, {
    String? fontFamily,
    BorderRadius? surfaceRadius,
    double? spacingBase,
    double zoomFactor = 1.0,
  }) {
    final baseTheme = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      fontFamily: fontFamily,
    );
    final radius = surfaceRadius ?? BorderRadius.circular(2 * zoomFactor);
    return AppThemeTokens(
      spacing: AppSpacing(base: spacingBase ?? 4, zoomFactor: zoomFactor),
      tabChip: AppTabChipTokens.fromScheme(scheme, zoomFactor: zoomFactor),
      list: AppListTokens.fromScheme(scheme),
      section: AppSectionTokens.fromScheme(
        scheme,
        surfaceRadius: radius,
        zoomFactor: zoomFactor,
      ),
      typography: AppTypographyTokens.fromTextTheme(
        baseTheme.textTheme,
        zoomFactor: zoomFactor,
      ),
      icons: AppIcons.nerd(),
      iconSizes: AppIconsTokens(zoomFactor: zoomFactor),
      dimensions: AppDimensionsTokens(zoomFactor: zoomFactor),
      docker: AppDockerTokens.fromScheme(scheme),
      distroColors: DistroColors.standard(),
    );
  }

  @override
  ThemeExtension<AppThemeTokens> copyWith({
    AppSpacing? spacing,
    AppTabChipTokens? tabChip,
    AppListTokens? list,
    AppSectionTokens? section,
    AppTypographyTokens? typography,
    AppIcons? icons,
    AppIconsTokens? iconSizes,
    AppDimensionsTokens? dimensions,
    AppDockerTokens? docker,
    DistroColors? distroColors,
  }) {
    return AppThemeTokens(
      spacing: spacing ?? this.spacing,
      tabChip: tabChip ?? this.tabChip,
      list: list ?? this.list,
      section: section ?? this.section,
      typography: typography ?? this.typography,
      icons: icons ?? this.icons,
      iconSizes: iconSizes ?? this.iconSizes,
      dimensions: dimensions ?? this.dimensions,
      docker: docker ?? this.docker,
      distroColors: distroColors ?? this.distroColors,
    );
  }

  @override
  ThemeExtension<AppThemeTokens> lerp(
    ThemeExtension<AppThemeTokens>? other,
    double t,
  ) {
    if (other is! AppThemeTokens) {
      return this;
    }
    return AppThemeTokens(
      spacing: spacing,
      tabChip: AppTabChipTokens.lerp(tabChip, other.tabChip, t),
      list: AppListTokens.lerp(list, other.list, t),
      section: AppSectionTokens.lerp(section, other.section, t),
      typography: AppTypographyTokens.lerp(typography, other.typography, t),
      icons: icons,
      iconSizes: AppIconsTokens.lerp(iconSizes, other.iconSizes, t),
      dimensions: AppDimensionsTokens.lerp(dimensions, other.dimensions, t),
      docker: AppDockerTokens.lerp(docker, other.docker, t),
      distroColors: DistroColors.lerp(distroColors, other.distroColors, t),
    );
  }
}

class AppSpacing {
  const AppSpacing({this.base = 4, this.zoomFactor = 1.0});

  final double base;
  final double zoomFactor;

  double get effectiveBase => base * zoomFactor;

  double get xs => effectiveBase * 0.5;
  double get sm => effectiveBase;
  double get md => effectiveBase * 2;
  double get lg => effectiveBase * 3;
  double get xl => effectiveBase * 4;

  EdgeInsets inset({double horizontal = 1, double vertical = 1}) {
    return EdgeInsets.symmetric(
      horizontal: effectiveBase * horizontal,
      vertical: effectiveBase * vertical,
    );
  }

  EdgeInsets all(double factor) => EdgeInsets.all(effectiveBase * factor);
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

  factory AppTypographyTokens.fromTextTheme(
    TextTheme textTheme, {
    double zoomFactor = 1.0,
  }) {
    // Note: TextScaler in MediaQuery handles text scaling, but we ensure
    // fallback sizes also scale for consistency
    return AppTypographyTokens(
      sectionTitle: (textTheme.titleLarge ??
              const TextStyle(fontSize: 20, fontWeight: FontWeight.w600))
          .copyWith(fontSize: 20 * zoomFactor),
      body: (textTheme.bodyMedium ?? const TextStyle(fontSize: 14))
          .copyWith(fontSize: 14 * zoomFactor),
      caption: (textTheme.bodySmall ?? const TextStyle(fontSize: 12))
          .copyWith(fontSize: 12 * zoomFactor),
      code: (textTheme.bodySmall ?? const TextStyle())
          .copyWith(
            fontFamily: 'monospace',
            fontSize: 12 * zoomFactor,
          ),
      tabLabel: (textTheme.labelLarge ??
              const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))
          .copyWith(fontSize: 14 * zoomFactor),
    );
  }

  static AppTypographyTokens lerp(
    AppTypographyTokens a,
    AppTypographyTokens b,
    double t,
  ) {
    return AppTypographyTokens(
      sectionTitle:
          TextStyle.lerp(a.sectionTitle, b.sectionTitle, t) ?? a.sectionTitle,
      body: TextStyle.lerp(a.body, b.body, t) ?? a.body,
      caption: TextStyle.lerp(a.caption, b.caption, t) ?? a.caption,
      code: TextStyle.lerp(a.code, b.code, t) ?? a.code,
      tabLabel: TextStyle.lerp(a.tabLabel, b.tabLabel, t) ?? a.tabLabel,
    );
  }
}

extension BuildContextAppTheme on BuildContext {
  AppThemeTokens get appTheme => Theme.of(this).extension<AppThemeTokens>()!;

  /// Get the current zoom factor from MediaQuery text scaler
  double get zoomFactor => MediaQuery.of(this).textScaler.scale(1.0);

  /// Scale a value by the current zoom factor
  double scale(double value) => value * zoomFactor;

  /// Get spacing that dynamically scales with current zoom factor
  /// This ensures spacing updates immediately when zoom changes,
  /// unlike the theme's baked-in spacing values.
  /// Use this instead of appTheme.spacing for responsive spacing.
  AppSpacing get spacing {
    final themeSpacing = appTheme.spacing;
    // Use current zoom factor from MediaQuery instead of baked-in value
    // This ensures spacing updates immediately when zoom changes
    return AppSpacing(base: themeSpacing.base, zoomFactor: zoomFactor);
  }

  /// Get icon sizes that dynamically scale with current zoom factor
  /// Use this instead of appTheme.iconSizes for responsive icon sizes.
  AppIconsTokens get iconSizes {
    // Use current zoom factor from MediaQuery instead of baked-in value
    return AppIconsTokens(zoomFactor: zoomFactor);
  }

  /// Get dimensions that dynamically scale with current zoom factor
  /// Use this instead of appTheme.dimensions for responsive dimensions.
  AppDimensionsTokens get dimensions {
    // Use current zoom factor from MediaQuery instead of baked-in value
    return AppDimensionsTokens(zoomFactor: zoomFactor);
  }
}

double lerpDouble(double a, double b, double t) => a + (b - a) * t;
