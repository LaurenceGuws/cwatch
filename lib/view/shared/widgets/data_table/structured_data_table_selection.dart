// ignore_for_file: annotate_overrides
part of 'structured_data_table.dart';

mixin _StructuredDataTableSelection<T> on _StructuredDataTableStateBase<T> {
  StructuredDataTableCellSelectionState get _cellSelectionState =>
      const StructuredDataTableCellSelectionState();

  StructuredDataTableCellSelectionSnapshot get _cellSelectionSnapshot =>
      StructuredDataTableCellSelectionSnapshot(
        selectedCell: _selectedCell,
        focusedCell: _focusedCell,
        anchor: _cellSelectionAnchor,
        extent: _cellSelectionExtent,
        additionalSelectedCells: Set<StructuredDataCellCoordinate>.from(
          _additionalSelectedCells,
        ),
      );

  void _clearTableSelection({bool clearFocus = false}) {
    final hadExternalSelection =
        !widget.rowSelectionEnabled &&
        (widget.selectedRowsBuilder != null || widget.rowSelectionPredicate != null) &&
        _selectedRows().isNotEmpty;
      _listController.clearSelection(clearFocus: clearFocus);
      if (!widget.cellSelectionEnabled) {
      if (hadExternalSelection) {
        widget.onSelectionChanged?.call(<T>[]);
      }
      return;
    }
    setState(() {
      _selectedCell = null;
      _focusedCell = null;
      _cellSelectionAnchor = null;
      _cellSelectionExtent = null;
      _additionalSelectedCells.clear();
      _cellEditMode = false;
    });
    if (hadExternalSelection) {
      widget.onSelectionChanged?.call(<T>[]);
    }
  }

  void _setMarqueeSelecting(bool value) {
    if (!mounted) return;
    if (_isMarqueeSelecting == value) return;
    setState(() => _isMarqueeSelecting = value);
  }

  void _setRowDragAnchor(int? rowIndex, int? pointer) {
    if (!mounted) return;
    if (_rowDragAnchorIndex == rowIndex && _rowDragPointer == pointer) return;
    setState(() {
      _rowDragAnchorIndex = rowIndex;
      _rowDragPointer = pointer;
    });
  }

  void _handleSelectionChanged() {
    if (!mounted) return;
    setState(() {});
    widget.onSelectionChanged?.call(_selectedRows());
    if (!widget.cellSelectionEnabled) {
      final focused = _listController.focusedIndex;
      if (focused != null && mounted) {
        _scheduleScrollToRow(focused, context);
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
    final coordinate = _cellSelectionState.clampCoordinate(
      rowIndex: rowIndex,
      columnIndex: columnIndex,
      rowCount: _visibleRows.length,
      columnCount: _columns.length,
    );
    final clampedRow = coordinate.rowIndex;
    final clampedColumn = coordinate.columnIndex;
    if (_selectedCell == coordinate) {
      _listController.focus(clampedRow);
      _focusedCell = coordinate;
      return;
    }
    final nextState = _cellSelectionState.updateSelection(
      current: _cellSelectionSnapshot,
      coordinate: coordinate,
      extend: extend,
    );
    setState(() {
      _selectedCell = nextState.selectedCell;
      _focusedCell = nextState.focusedCell;
      _cellSelectionAnchor = nextState.anchor;
      _cellSelectionExtent = nextState.extent;
      _additionalSelectedCells
        ..clear()
        ..addAll(nextState.additionalSelectedCells);
    });
    _listController.focus(clampedRow);
    if (!_focusNode.hasFocus) {
      _focusNode.requestFocus();
    }
    if (notify) {
      widget.onCellTap?.call(coordinate);
    }
    _scheduleScrollToRow(clampedRow, context);
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
    return _cellSelectionState.isCellSelected(
      current: _cellSelectionSnapshot,
      rowIndex: rowIndex,
      columnIndex: columnIndex,
    );
  }

  bool _isHoveredCell(int rowIndex, int columnIndex) {
    if (!widget.cellSelectionEnabled) return false;
    final hovered = _hoveredCell;
    if (hovered == null) return false;
    return hovered.rowIndex == rowIndex && hovered.columnIndex == columnIndex;
  }

  void _beginMarqueeSelection(Offset localPosition, BuildContext context) {
    final coordinate = _cellCoordinateForOffset(localPosition, context);
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
    final nextState = _cellSelectionState.beginMarquee(coordinate: coordinate);
    setState(() {
      _selectedCell = nextState.selectedCell;
      _focusedCell = nextState.focusedCell;
      _cellSelectionAnchor = nextState.anchor;
      _cellSelectionExtent = nextState.extent;
      _additionalSelectedCells
        ..clear()
        ..addAll(nextState.additionalSelectedCells);
    });
  }

  void _updateMarqueeSelection(Offset localPosition, BuildContext context) {
    final coordinate = _cellCoordinateForOffset(localPosition, context);
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
    final coordinate = _cellSelectionState.clampCoordinate(
      rowIndex: rowIndex,
      columnIndex: columnIndex,
      rowCount: _visibleRows.length,
      columnCount: _columns.length,
    );
    final clampedRow = coordinate.rowIndex;
    final clampedColumn = coordinate.columnIndex;
    if (_focusedCell == coordinate) {
      _listController.focus(clampedRow);
      return;
    }
    final nextState = _cellSelectionState.updateFocus(
      current: _cellSelectionSnapshot,
      coordinate: coordinate,
    );
    setState(() {
      _focusedCell = nextState.focusedCell;
    });
    _listController.focus(clampedRow);
    if (!_focusNode.hasFocus) {
      _focusNode.requestFocus();
    }
    _scheduleScrollToRow(clampedRow, context);
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
