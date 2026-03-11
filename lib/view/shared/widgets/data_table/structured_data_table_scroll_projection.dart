part of 'structured_data_table.dart';

class StructuredDataTableScrollProjection {
  const StructuredDataTableScrollProjection();

  int pageStep({
    required double viewport,
    required double rowExtent,
    required int fallback,
  }) {
    if (viewport <= 0 || rowExtent <= 0) {
      return fallback;
    }
    return max(1, (viewport / rowExtent).floor());
  }

  double revealRowOffset({
    required int rowIndex,
    required double rowExtent,
    required double currentOffset,
    required double viewport,
    required double minOffset,
    required double maxOffset,
  }) {
    var target = currentOffset;
    final rowTop = rowIndex * rowExtent;
    final rowBottom = rowTop + rowExtent;
    if (rowTop < currentOffset) {
      target = rowTop;
    } else if (rowBottom > currentOffset + viewport) {
      target = rowBottom - viewport;
    }
    return target.clamp(minOffset, maxOffset);
  }

  double revealColumnOffset({
    required int columnIndex,
    required List<double> columnWidths,
    required double currentOffset,
    required double viewport,
    required double minOffset,
    required double maxOffset,
    required double rowPaddingX,
    required double gapWidth,
  }) {
    if (columnIndex < 0 || columnIndex >= columnWidths.length) {
      return currentOffset;
    }
    var left = rowPaddingX;
    for (var i = 0; i < columnIndex; i++) {
      left += columnWidths[i];
      left += gapWidth;
    }
    final right = left + columnWidths[columnIndex];
    var target = currentOffset;
    if (left < currentOffset) {
      target = left;
    } else if (right > currentOffset + viewport) {
      target = right - viewport;
    }
    return target.clamp(minOffset, maxOffset);
  }
}
