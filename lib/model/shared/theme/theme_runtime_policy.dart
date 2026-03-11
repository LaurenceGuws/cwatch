import 'package:flutter/material.dart';

import 'package:cwatch/model/models/app_settings.dart';

class ThemeRuntimePolicy {
  const ThemeRuntimePolicy({
    required this.zoomFactor,
    required this.baseRadius,
    required this.spacingBase,
    required this.visualDensity,
  });

  final double zoomFactor;
  final BorderRadius baseRadius;
  final double spacingBase;
  final VisualDensity visualDensity;

  factory ThemeRuntimePolicy.fromSettings(AppSettings settings) {
    final zoomFactor = settings.zoomFactor.clamp(0.5, 2.0).toDouble();
    return ThemeRuntimePolicy(
      zoomFactor: zoomFactor,
      baseRadius: BorderRadius.circular(2 * zoomFactor),
      spacingBase: settings.uiDensity == AppUiDensity.comfy ? 5.0 : 4.0,
      visualDensity: settings.uiDensity == AppUiDensity.comfy
          ? VisualDensity.standard
          : VisualDensity.compact,
    );
  }

  double clampZoom(double value) => value.clamp(0.5, 2.0).toDouble();

  TextScaler textScalerFor(AppSettings settings) {
    return TextScaler.linear(clampZoom(settings.zoomFactor));
  }
}
