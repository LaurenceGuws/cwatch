part of 'package:cwatch/model/shared/theme/app_theme.dart';

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

  factory AppSectionTokens.fromScheme(
    ColorScheme scheme, {
    required BorderRadius surfaceRadius,
    double zoomFactor = 1.0,
  }) {
    return AppSectionTokens(
      toolbarBackground: scheme.surface,
      divider: scheme.outlineVariant,
      surface: AppSurfaceStyle(
        background: scheme.surfaceContainerHigh,
        borderColor: scheme.outlineVariant.withValues(alpha: 0.6),
        radius: surfaceRadius,
        padding: EdgeInsets.symmetric(
          horizontal: 6 * zoomFactor,
          vertical: 4 * zoomFactor,
        ),
        margin: EdgeInsets.zero,
        elevation: 0.5,
      ),
    );
  }

  static AppSectionTokens lerp(
    AppSectionTokens a,
    AppSectionTokens b,
    double t,
  ) {
    return AppSectionTokens(
      toolbarBackground:
          Color.lerp(a.toolbarBackground, b.toolbarBackground, t) ??
          a.toolbarBackground,
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
