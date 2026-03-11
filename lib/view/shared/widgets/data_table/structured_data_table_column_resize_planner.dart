part of 'structured_data_table.dart';

class StructuredDataTableAutoFitResult {
  const StructuredDataTableAutoFitResult({
    required this.maxMeasuredWidth,
    required this.targetWidth,
  });

  final double maxMeasuredWidth;
  final double targetWidth;
}

class StructuredDataTableColumnResizePlanner<T> {
  const StructuredDataTableColumnResizePlanner();

  double clampWidth(double target, double minWidth, double maxWidth) {
    if (!maxWidth.isFinite) return max(minWidth, target);
    if (maxWidth <= minWidth) return minWidth;
    return target.clamp(minWidth, maxWidth);
  }

  double resizedWidth({
    required double currentWidth,
    required double delta,
    required double minWidth,
    required double maxWidth,
  }) {
    return clampWidth(currentWidth + delta, minWidth, maxWidth);
  }

  StructuredDataTableAutoFitResult autoFitWidth({
    required StructuredDataColumn<T> column,
    required List<T> visibleRows,
    required double cachedMeasuredWidth,
    required double Function(String text, TextStyle? style) measureText,
    required TextStyle? headerStyle,
    required TextStyle? cellStyle,
    required double Function(T row)? widthExtractor,
    required double maxSamples,
  }) {
    final extractor = column.autoFitText;
    final headerWidth = measureText(column.label, headerStyle);
    var maxWidth = max(cachedMeasuredWidth, headerWidth);
    final sampleCount = min(visibleRows.length, maxSamples.toInt());
    for (var i = 0; i < sampleCount; i++) {
      final row = visibleRows[i];
      if (widthExtractor != null) {
        maxWidth = max(maxWidth, widthExtractor(row));
      } else if (extractor != null) {
        maxWidth = max(maxWidth, measureText(extractor(row), cellStyle));
      }
    }

    final paddingWidth = measureText('M', cellStyle);
    return StructuredDataTableAutoFitResult(
      maxMeasuredWidth: maxWidth,
      targetWidth: maxWidth + paddingWidth + (column.autoFitExtraWidth ?? 0),
    );
  }
}
