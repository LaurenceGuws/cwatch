// ignore_for_file: annotate_overrides
part of 'structured_data_table.dart';

mixin _StructuredDataTableScrolling<T> on _StructuredDataTableStateBase<T> {
  StructuredDataTableScrollProjection get _scrollProjection =>
      const StructuredDataTableScrollProjection();

  int _pageStep(BuildContext context) {
    if (!_verticalController.hasClients) {
      return 10;
    }
    final dividerHeight = context.appTheme.dimensions.dividerHeight;
    final rowExtent = widget.rowHeight + dividerHeight;
    final viewport = _verticalController.position.viewportDimension;
    return _scrollProjection.pageStep(
      viewport: viewport,
      rowExtent: rowExtent,
      fallback: 10,
    );
  }

  void _scrollToRow(int rowIndex, BuildContext context) {
    if (!_verticalController.hasClients) {
      return;
    }
    final dividerHeight = context.appTheme.dimensions.dividerHeight;
    final rowExtent = widget.rowHeight + dividerHeight;
    final position = _verticalController.position;
    final viewport = position.viewportDimension;
    final minOffset = position.minScrollExtent;
    final maxOffset = position.maxScrollExtent;
    final target = _scrollProjection.revealRowOffset(
      rowIndex: rowIndex,
      rowExtent: rowExtent,
      currentOffset: position.pixels,
      viewport: viewport,
      minOffset: minOffset,
      maxOffset: maxOffset,
    );
    if ((target - position.pixels).abs() < 1) {
      return;
    }
    _verticalController.jumpTo(target);
  }

  void _scrollToColumn(int columnIndex) {
    if (!_horizontalController.hasClients || _lastColumnWidths.isEmpty) {
      return;
    }
    if (columnIndex < 0 || columnIndex >= _lastColumnWidths.length) {
      return;
    }
    final position = _horizontalController.position;
    final viewport = position.viewportDimension;
    final minOffset = position.minScrollExtent;
    final maxOffset = position.maxScrollExtent;
    final target = _scrollProjection.revealColumnOffset(
      columnIndex: columnIndex,
      columnWidths: _lastColumnWidths,
      currentOffset: position.pixels,
      viewport: viewport,
      minOffset: minOffset,
      maxOffset: maxOffset,
      rowPaddingX: _lastRowPaddingX,
      gapWidth: _lastGapWidth,
    );
    if ((target - position.pixels).abs() < 1) {
      return;
    }
    _horizontalController.jumpTo(target);
  }

  void _scheduleScrollToRow(int rowIndex, BuildContext context) {
    _scrollScheduleState = _scrollScheduleState.queueRow(rowIndex);
    if (_scrollScheduleState.rowScheduled) {
      return;
    }
    _scrollScheduleState = _scrollScheduleState.markRowScheduled();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final flush = _scrollScheduleState.flushRow();
      _scrollScheduleState = flush.nextState;
      final targetRow = flush.target;
      if (!mounted || targetRow == null) {
        return;
      }
      _scrollToRow(targetRow, context);
    });
  }

  void _scheduleScrollToColumn(int columnIndex) {
    _scrollScheduleState = _scrollScheduleState.queueColumn(columnIndex);
    if (_scrollScheduleState.columnScheduled) {
      return;
    }
    _scrollScheduleState = _scrollScheduleState.markColumnScheduled();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final flush = _scrollScheduleState.flushColumn();
      _scrollScheduleState = flush.nextState;
      final targetColumn = flush.target;
      if (!mounted || targetColumn == null) {
        return;
      }
      _scrollToColumn(targetColumn);
    });
  }
}
