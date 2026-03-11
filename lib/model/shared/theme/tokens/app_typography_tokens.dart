part of 'package:cwatch/model/shared/theme/app_theme.dart';

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
    return AppTypographyTokens(
      sectionTitle: (textTheme.titleLarge ??
              const TextStyle(fontSize: 20, fontWeight: FontWeight.w600))
          .copyWith(fontSize: 20 * zoomFactor),
      body: (textTheme.bodyMedium ?? const TextStyle(fontSize: 14))
          .copyWith(fontSize: 14 * zoomFactor),
      caption: (textTheme.bodySmall ?? const TextStyle(fontSize: 12))
          .copyWith(fontSize: 12 * zoomFactor),
      code: (textTheme.bodySmall ?? const TextStyle()).copyWith(
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
