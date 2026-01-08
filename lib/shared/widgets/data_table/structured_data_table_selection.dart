// ignore_for_file: annotate_overrides
part of 'structured_data_table.dart';

mixin _StructuredDataTableSelection<T> on _StructuredDataTableStateBase<T> {
  void _setMarqueeSelecting(bool value) {
    if (_isMarqueeSelecting == value) return;
    setState(() => _isMarqueeSelecting = value);
  }

  void _setRowDragAnchor(int? rowIndex, int? pointer) {
    if (_rowDragAnchorIndex == rowIndex && _rowDragPointer == pointer) return;
    setState(() {
      _rowDragAnchorIndex = rowIndex;
      _rowDragPointer = pointer;
    });
  }

  void _handleSelectionChanged() {
    setState(() {});
    widget.onSelectionChanged?.call(_selectedRows());
    if (!widget.cellSelectionEnabled) {
      final focused = _listController.focusedIndex;
      if (focused != null) {
        _scheduleScrollToRow(focused);
      }
    }
  }

  List<T> _selectedRows() {
    final builder = widget.selectedRowsBuilder;
    if (builder != null) {
      return builder(_visibleRows);
    }
    return _listController.selectedIndices
        .where((index) => index < _visibleRows.length)
        .map((index) => _visibleRows[index])
        .toList(growable: false);
  }

  void _selectSingle(int index) {
    _listController.selectSingle(index);
  }

  void _handleRowTapSelection(int index) {
    if (!widget.rowSelectionEnabled) {
      return;
    }
    final focusNode = widget.focusNode ?? _focusNode;
    if (!focusNode.hasFocus) {
      focusNode.requestFocus();
    }
    if (!widget.allowMultiSelect) {
      _selectSingle(index);
      return;
    }
    final hardware = HardwareKeyboard.instance;
    final isShift = hardware.isShiftPressed;
    final isControl = hardware.isControlPressed || hardware.isMetaPressed;
    if (isShift) {
      _listController.extendSelection(index);
      return;
    }
    if (isControl) {
      _listController.toggle(index);
      return;
    }
    _selectSingle(index);
  }

  void _handleDoubleTap(int index) {
    if (_visibleRows.isEmpty) return;
    if (!widget.cellSelectionEnabled && widget.rowSelectionEnabled) {
      _selectSingle(index);
    }
    widget.onRowDoubleTap?.call(_visibleRows[index]);
  }

  void _handleCellTap(int? rowIndex, int columnIndex) {
    if (!widget.cellSelectionEnabled ||
        rowIndex == null ||
        rowIndex >= _visibleRows.length ||
        columnIndex >= _columns.length) {
      return;
    }
    if (_cellEditMode) {
      _exitCellEditMode(commit: false);
    }
    _updateCellSelection(rowIndex: rowIndex, columnIndex: columnIndex);
  }

  void _updateCellSelection({
    required int rowIndex,
    required int columnIndex,
    bool extend = false,
    bool notify = true,
  }) {
    if (!widget.cellSelectionEnabled || _visibleRows.isEmpty) {
      return;
    }
    final clampedRow = rowIndex.clamp(0, _visibleRows.length - 1);
    final clampedColumn = columnIndex.clamp(0, _columns.length - 1);
    final coordinate = StructuredDataCellCoordinate(
      rowIndex: clampedRow,
      columnIndex: clampedColumn,
    );
    if (_selectedCell == coordinate) {
      _listController.focus(clampedRow);
      _focusedCell = coordinate;
      return;
    }
    setState(() {
      _selectedCell = coordinate;
      _focusedCell = coordinate;
      if (extend) {
        _cellSelectionAnchor ??= _cellSelectionExtent ?? coordinate;
        _cellSelectionExtent = coordinate;
      } else {
        _cellSelectionAnchor = coordinate;
        _cellSelectionExtent = coordinate;
        _additionalSelectedCells.clear();
      }
    });
    _listController.focus(clampedRow);
    if (!_focusNode.hasFocus) {
      _focusNode.requestFocus();
    }
    if (notify) {
      widget.onCellTap?.call(coordinate);
    }
    _scheduleScrollToRow(clampedRow);
    _scheduleScrollToColumn(clampedColumn);
  }

  void _ensureCellFocus() {
    if (!widget.cellSelectionEnabled || _visibleRows.isEmpty) {
      return;
    }
    if (_focusedCell != null || _selectedCell != null) {
      return;
    }
    final fallbackRow = _listController.focusedIndex ?? 0;
    _updateCellFocus(rowIndex: fallbackRow, columnIndex: 0);
  }

  bool _isCellSelected(int rowIndex, int columnIndex) {
    if (!widget.cellSelectionEnabled) return false;
    if (_additionalSelectedCells.contains(
      StructuredDataCellCoordinate(
        rowIndex: rowIndex,
        columnIndex: columnIndex,
      ),
    )) {
      return true;
    }
    final anchor = _cellSelectionAnchor;
    final extent = _cellSelectionExtent ?? _selectedCell;
    if (anchor == null || extent == null) return false;
    final top = min(anchor.rowIndex, extent.rowIndex);
    final bottom = max(anchor.rowIndex, extent.rowIndex);
    final left = min(anchor.columnIndex, extent.columnIndex);
    final right = max(anchor.columnIndex, extent.columnIndex);
    return rowIndex >= top &&
        rowIndex <= bottom &&
        columnIndex >= left &&
        columnIndex <= right;
  }

  bool _isHoveredCell(int rowIndex, int columnIndex) {
    if (!widget.cellSelectionEnabled) return false;
    final hovered = _hoveredCell;
    if (hovered == null) return false;
    return hovered.rowIndex == rowIndex && hovered.columnIndex == columnIndex;
  }

  void _beginMarqueeSelection(Offset localPosition) {
    final coordinate = _cellCoordinateForOffset(localPosition);
    if (coordinate == null) return;
    final isShift = HardwareKeyboard.instance.isShiftPressed;
    if (!isShift &&
        _isCellSelected(coordinate.rowIndex, coordinate.columnIndex)) {
      setState(() {
        _focusedCell = coordinate;
      });
      return;
    }
    if (_cellEditMode) {
      _exitCellEditMode(commit: false);
    }
    setState(() {
      _selectedCell = coordinate;
      _focusedCell = coordinate;
      _cellSelectionAnchor = coordinate;
      _cellSelectionExtent = coordinate;
      _additionalSelectedCells.clear();
    });
  }

  void _updateMarqueeSelection(Offset localPosition) {
    final coordinate = _cellCoordinateForOffset(localPosition);
    if (coordinate == null) return;
    setState(() {
      _selectedCell = coordinate;
      _focusedCell = coordinate;
      _cellSelectionExtent = coordinate;
    });
  }

  void _updateCellFocus({required int rowIndex, required int columnIndex}) {
    if (!widget.cellSelectionEnabled || _visibleRows.isEmpty) {
      return;
    }
    final clampedRow = rowIndex.clamp(0, _visibleRows.length - 1);
    final clampedColumn = columnIndex.clamp(0, _columns.length - 1);
    final coordinate = StructuredDataCellCoordinate(
      rowIndex: clampedRow,
      columnIndex: clampedColumn,
    );
    if (_focusedCell == coordinate) {
      _listController.focus(clampedRow);
      return;
    }
    setState(() {
      _focusedCell = coordinate;
    });
    _listController.focus(clampedRow);
    if (!_focusNode.hasFocus) {
      _focusNode.requestFocus();
    }
    _scheduleScrollToRow(clampedRow);
    _scheduleScrollToColumn(clampedColumn);
  }

  void _enterCellEditMode(StructuredDataCellCoordinate coordinate) {
    if (_cellEditMode) return;
    setState(() {
      _cellEditMode = true;
    });
    widget.onCellEditRequested?.call(coordinate);
  }

  void _exitCellEditMode({required bool commit}) {
    if (!_cellEditMode) return;
    final coordinate = _selectedCell ?? _focusedCell;
    setState(() {
      _cellEditMode = false;
    });
    if (coordinate == null) return;
    if (commit) {
      widget.onCellEditCommitted?.call(coordinate);
    } else {
      widget.onCellEditCanceled?.call(coordinate);
    }
  }
}
