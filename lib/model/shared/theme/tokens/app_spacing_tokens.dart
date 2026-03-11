part of 'package:cwatch/model/shared/theme/app_theme.dart';

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
