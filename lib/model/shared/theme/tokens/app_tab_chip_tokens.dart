part of 'package:cwatch/model/shared/theme/app_theme.dart';

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

  factory AppTabChipTokens.fromScheme(
    ColorScheme scheme, {
    double zoomFactor = 1.0,
  }) {
    return AppTabChipTokens(
      selectedBackground: scheme.primaryContainer,
      unselectedBackground: Colors.transparent,
      selectedForeground: scheme.onPrimaryContainer,
      unselectedForeground: scheme.onSurfaceVariant,
      selectedBorder: scheme.primary,
      unselectedBorder: scheme.outlineVariant,
      borderRadius: BorderRadius.circular(2 * zoomFactor),
      horizontalPadding: 0.4,
      verticalPadding: 0.12,
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

  static AppTabChipTokens lerp(
    AppTabChipTokens a,
    AppTabChipTokens b,
    double t,
  ) {
    return AppTabChipTokens(
      selectedBackground:
          Color.lerp(a.selectedBackground, b.selectedBackground, t) ??
          a.selectedBackground,
      unselectedBackground:
          Color.lerp(a.unselectedBackground, b.unselectedBackground, t) ??
          a.unselectedBackground,
      selectedForeground:
          Color.lerp(a.selectedForeground, b.selectedForeground, t) ??
          a.selectedForeground,
      unselectedForeground:
          Color.lerp(a.unselectedForeground, b.unselectedForeground, t) ??
          a.unselectedForeground,
      selectedBorder:
          Color.lerp(a.selectedBorder, b.selectedBorder, t) ?? a.selectedBorder,
      unselectedBorder:
          Color.lerp(a.unselectedBorder, b.unselectedBorder, t) ??
          a.unselectedBorder,
      borderRadius:
          BorderRadius.lerp(a.borderRadius, b.borderRadius, t) ??
          a.borderRadius,
      horizontalPadding: lerpDouble(
        a.horizontalPadding,
        b.horizontalPadding,
        t,
      ),
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
