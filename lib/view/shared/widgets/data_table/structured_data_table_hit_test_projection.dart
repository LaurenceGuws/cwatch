part of 'structured_data_table.dart';

class StructuredDataTableEdgeScrollDelta {
  const StructuredDataTableEdgeScrollDelta({
    required this.vertical,
    required this.horizontal,
  });

  final double vertical;
  final double horizontal;
}

class StructuredDataTableHitTestProjection {
  const StructuredDataTableHitTestProjection();

  StructuredDataTableEdgeScrollDelta edgeScrollDelta({
    required Offset localPosition,
    required Size viewportSize,
    required double edgeThreshold,
    required double scrollStep,
  }) {
    var vertical = 0.0;
    if (localPosition.dy < edgeThreshold) {
      vertical = -scrollStep;
    } else if (localPosition.dy > viewportSize.height - edgeThreshold) {
      vertical = scrollStep;
    }

    var horizontal = 0.0;
    if (localPosition.dx < edgeThreshold) {
      horizontal = -scrollStep;
    } else if (localPosition.dx > viewportSize.width - edgeThreshold) {
      horizontal = scrollStep;
    }

    return StructuredDataTableEdgeScrollDelta(
      vertical: vertical,
      horizontal: horizontal,
    );
  }

  int? rowIndexForOffset({
    required Offset localPosition,
    required int rowCount,
    required double rowExtent,
    required double verticalOffset,
  }) {
    if (rowCount == 0) return null;
    final contentY = localPosition.dy + verticalOffset;
    final rowIndex = (contentY / rowExtent).floor();
    if (rowIndex < 0 || rowIndex >= rowCount) {
      return null;
    }
    return rowIndex;
  }

  int columnIndexForLocalDx({
    required double localDx,
    required List<double> columnWidths,
    required double horizontalOffset,
    required double rowPaddingX,
    required double gapWidth,
  }) {
    if (columnWidths.isEmpty) {
      return 0;
    }
    var contentX = localDx + horizontalOffset - rowPaddingX;
    if (contentX <= 0) return 0;
    for (var i = 0; i < columnWidths.length; i++) {
      final width = columnWidths[i];
      if (contentX < width) {
        return i;
      }
      contentX -= width + gapWidth;
    }
    return columnWidths.length - 1;
  }

  StructuredDataCellCoordinate? cellCoordinateForOffset({
    required Offset localPosition,
    required int rowCount,
    required List<double> columnWidths,
    required double rowExtent,
    required double verticalOffset,
    required double horizontalOffset,
    required double rowPaddingX,
    required double gapWidth,
  }) {
    final rowIndex = rowIndexForOffset(
      localPosition: localPosition,
      rowCount: rowCount,
      rowExtent: rowExtent,
      verticalOffset: verticalOffset,
    );
    if (rowIndex == null || columnWidths.isEmpty) {
      return null;
    }
    return StructuredDataCellCoordinate(
      rowIndex: rowIndex,
      columnIndex: columnIndexForLocalDx(
        localDx: localPosition.dx,
        columnWidths: columnWidths,
        horizontalOffset: horizontalOffset,
        rowPaddingX: rowPaddingX,
        gapWidth: gapWidth,
      ),
    );
  }
}
