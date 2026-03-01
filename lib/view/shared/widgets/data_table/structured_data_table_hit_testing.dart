// ignore_for_file: annotate_overrides
part of 'structured_data_table.dart';

mixin _StructuredDataTableHitTesting<T> on _StructuredDataTableStateBase<T> {
  void _applyEdgeScroll(Offset localPosition, BuildContext context) {
    final renderBox = _bodyKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final size = renderBox.size;
    final zoomFactor = context.zoomFactor;
    final edgeThreshold = 24.0 * zoomFactor;
    final scrollStep = 18.0 * zoomFactor;

    var verticalDelta = 0.0;
    if (localPosition.dy < edgeThreshold) {
      verticalDelta = -scrollStep;
    } else if (localPosition.dy > size.height - edgeThreshold) {
      verticalDelta = scrollStep;
    }

    var horizontalDelta = 0.0;
    if (localPosition.dx < edgeThreshold) {
      horizontalDelta = -scrollStep;
    } else if (localPosition.dx > size.width - edgeThreshold) {
      horizontalDelta = scrollStep;
    }

    if (verticalDelta != 0 && _verticalController.hasClients) {
      final position = _verticalController.position;
      final next = (position.pixels + verticalDelta).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      _verticalController.jumpTo(next);
    }

    if (horizontalDelta != 0 && _horizontalController.hasClients) {
      final position = _horizontalController.position;
      final next = (position.pixels + horizontalDelta).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      _horizontalController.jumpTo(next);
    }
  }

  StructuredDataCellCoordinate? _cellCoordinateForOffset(
    Offset localPosition,
    BuildContext context,
  ) {
    if (_visibleRows.isEmpty || _columns.isEmpty || _lastColumnWidths.isEmpty) {
      return null;
    }
    final dividerHeight = context.appTheme.dimensions.dividerHeight;
    final rowExtent = widget.rowHeight + dividerHeight;
    final contentY = localPosition.dy + _verticalController.offset;
    final rowIndex = (contentY / rowExtent).floor();
    if (rowIndex < 0 || rowIndex >= _visibleRows.length) {
      return null;
    }
    var contentX =
        localPosition.dx + _horizontalController.offset - _lastRowPaddingX;
    if (contentX <= 0) {
      return StructuredDataCellCoordinate(rowIndex: rowIndex, columnIndex: 0);
    }
    for (var i = 0; i < _lastColumnWidths.length; i++) {
      final width = _lastColumnWidths[i];
      if (contentX < width) {
        return StructuredDataCellCoordinate(rowIndex: rowIndex, columnIndex: i);
      }
      contentX -= width + _lastGapWidth;
    }
    return StructuredDataCellCoordinate(
      rowIndex: rowIndex,
      columnIndex: _lastColumnWidths.length - 1,
    );
  }

  int _columnIndexForLocalDx(double localDx) {
    if (_columns.isEmpty || _lastColumnWidths.isEmpty) {
      return 0;
    }
    var contentX = localDx + _horizontalController.offset - _lastRowPaddingX;
    if (contentX <= 0) return 0;
    for (var i = 0; i < _lastColumnWidths.length; i++) {
      final width = _lastColumnWidths[i];
      if (contentX < width) {
        return i;
      }
      contentX -= width + _lastGapWidth;
    }
    return _lastColumnWidths.length - 1;
  }

  int? _rowIndexForOffset(Offset localPosition, BuildContext context) {
    if (_visibleRows.isEmpty) return null;
    final dividerHeight = context.appTheme.dimensions.dividerHeight;
    final rowExtent = widget.rowHeight + dividerHeight;
    final contentY = localPosition.dy + _verticalController.offset;
    final rowIndex = (contentY / rowExtent).floor();
    if (rowIndex < 0 || rowIndex >= _visibleRows.length) {
      return null;
    }
    return rowIndex;
  }
}
