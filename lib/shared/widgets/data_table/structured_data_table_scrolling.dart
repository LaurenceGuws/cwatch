// ignore_for_file: annotate_overrides
part of 'structured_data_table.dart';

mixin _StructuredDataTableScrolling<T> on _StructuredDataTableStateBase<T> {
  int _pageStep() {
    if (!_verticalController.hasClients) {
      return 10;
    }
    final rowExtent = widget.rowHeight + 1;
    final viewport = _verticalController.position.viewportDimension;
    if (viewport <= 0) {
      return 10;
    }
    return max(1, (viewport / rowExtent).floor());
  }

  void _scrollToRow(int rowIndex) {
    if (!_verticalController.hasClients) {
      return;
    }
    final rowExtent = widget.rowHeight + 1;
    final position = _verticalController.position;
    final viewport = position.viewportDimension;
    final minOffset = position.minScrollExtent;
    final maxOffset = position.maxScrollExtent;
    var target = position.pixels;
    final rowTop = rowIndex * rowExtent;
    final rowBottom = rowTop + rowExtent;
    if (rowTop < position.pixels) {
      target = rowTop;
    } else if (rowBottom > position.pixels + viewport) {
      target = rowBottom - viewport;
    }
    target = target.clamp(minOffset, maxOffset);
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
    var left = _lastRowPaddingX;
    for (var i = 0; i < columnIndex; i++) {
      left += _lastColumnWidths[i];
      left += _lastGapWidth;
    }
    final right = left + _lastColumnWidths[columnIndex];
    var target = position.pixels;
    if (left < position.pixels) {
      target = left;
    } else if (right > position.pixels + viewport) {
      target = right - viewport;
    }
    target = target.clamp(minOffset, maxOffset);
    if ((target - position.pixels).abs() < 1) {
      return;
    }
    _horizontalController.jumpTo(target);
  }

  void _scheduleScrollToRow(int rowIndex) {
    _pendingScrollToRow = rowIndex;
    if (_scrollToRowScheduled) {
      return;
    }
    _scrollToRowScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToRowScheduled = false;
      final targetRow = _pendingScrollToRow;
      _pendingScrollToRow = null;
      if (!mounted || targetRow == null) {
        return;
      }
      _scrollToRow(targetRow);
    });
  }

  void _scheduleScrollToColumn(int columnIndex) {
    _pendingScrollToColumn = columnIndex;
    if (_scrollToColumnScheduled) {
      return;
    }
    _scrollToColumnScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToColumnScheduled = false;
      final targetColumn = _pendingScrollToColumn;
      _pendingScrollToColumn = null;
      if (!mounted || targetColumn == null) {
        return;
      }
      _scrollToColumn(targetColumn);
    });
  }
}
