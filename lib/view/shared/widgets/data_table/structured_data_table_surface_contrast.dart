part of 'structured_data_table.dart';

class StructuredDataTableSurfaceContrast {
  const StructuredDataTableSurfaceContrast();

  Brightness estimateBrightness(Color background) {
    return ThemeData.estimateBrightnessForColor(background);
  }

  Color headerBorderColor({
    required Color background,
    required Color outlineVariant,
  }) {
    final isLightBackground = estimateBrightness(background) == Brightness.light;
    return outlineVariant.withValues(alpha: isLightBackground ? 0.5 : 0.35);
  }

  Color dividerColor({
    required Color background,
    required Color outlineVariant,
  }) {
    final isLightBackground = estimateBrightness(background) == Brightness.light;
    return outlineVariant.withValues(alpha: isLightBackground ? 0.75 : 0.5);
  }
}
