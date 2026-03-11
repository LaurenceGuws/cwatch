// ignore_for_file: annotate_overrides
part of 'structured_data_table.dart';

mixin _StructuredDataTableHitTesting<T> on _StructuredDataTableStateBase<T> {
  StructuredDataTableHitTestProjection get _hitTestProjection =>
      const StructuredDataTableHitTestProjection();

  void _applyEdgeScroll(Offset localPosition, BuildContext context) {
    final renderBox = _bodyKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final size = renderBox.size;
    final zoomFactor = context.zoomFactor;
    final edgeThreshold = 24.0 * zoomFactor;
    final scrollStep = 18.0 * zoomFactor;
    final delta = _hitTestProjection.edgeScrollDelta(
      localPosition: localPosition,
      viewportSize: size,
      edgeThreshold: edgeThreshold,
      scrollStep: scrollStep,
    );
    final verticalDelta = delta.vertical;
    final horizontalDelta = delta.horizontal;

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
    return _hitTestProjection.cellCoordinateForOffset(
      localPosition: localPosition,
      rowCount: _visibleRows.length,
      columnWidths: _lastColumnWidths,
      rowExtent: widget.rowHeight + dividerHeight,
      verticalOffset: _verticalController.offset,
      horizontalOffset: _horizontalController.offset,
      rowPaddingX: _lastRowPaddingX,
      gapWidth: _lastGapWidth,
    );
  }

  int _columnIndexForLocalDx(double localDx) {
    return _hitTestProjection.columnIndexForLocalDx(
      localDx: localDx,
      columnWidths: _lastColumnWidths,
      horizontalOffset: _horizontalController.offset,
      rowPaddingX: _lastRowPaddingX,
      gapWidth: _lastGapWidth,
    );
  }

  int? _rowIndexForOffset(Offset localPosition, BuildContext context) {
    final dividerHeight = context.appTheme.dimensions.dividerHeight;
    return _hitTestProjection.rowIndexForOffset(
      localPosition: localPosition,
      rowCount: _visibleRows.length,
      rowExtent: widget.rowHeight + dividerHeight,
      verticalOffset: _verticalController.offset,
    );
  }
}
