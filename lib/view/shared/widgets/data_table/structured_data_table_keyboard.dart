// ignore_for_file: annotate_overrides
part of 'structured_data_table.dart';

mixin _StructuredDataTableKeyboard<T> on _StructuredDataTableStateBase<T> {
  StructuredDataTableCellNavigation<T> get _cellNavigation =>
      StructuredDataTableCellNavigation<T>();

  int _jumpRow(int startRow, int columnIndex, int delta) {
    return _cellNavigation.jumpRow(
      rows: _visibleRows,
      columns: _columns,
      startRow: startRow,
      columnIndex: columnIndex,
      delta: delta,
    );
  }

  int _jumpColumn(int rowIndex, int startColumn, int delta) {
    return _cellNavigation.jumpColumn(
      rows: _visibleRows,
      columns: _columns,
      rowIndex: rowIndex,
      startColumn: startColumn,
      delta: delta,
    );
  }

  KeyEventResult _handleCellKeyEvent(
    FocusNode node,
    KeyEvent event,
    BuildContext context,
  ) {
    if (event is! KeyDownEvent &&
        event is! KeyUpEvent &&
        event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (!widget.cellSelectionEnabled || _visibleRows.isEmpty) {
      return KeyEventResult.ignored;
    }
    _ensureCellFocus();
    final hardware = HardwareKeyboard.instance;
    final isShift = hardware.isShiftPressed;
    final isControl = hardware.isControlPressed || hardware.isMetaPressed;
    final current =
        _focusedCell ??
        _selectedCell ??
        StructuredDataCellCoordinate(
          rowIndex: _listController.focusedIndex ?? 0,
          columnIndex: 0,
        );
    final key = event.logicalKey;
    if (event is KeyUpEvent) {
      final isHandledKey =
          key == LogicalKeyboardKey.arrowUp ||
          key == LogicalKeyboardKey.arrowDown ||
          key == LogicalKeyboardKey.arrowLeft ||
          key == LogicalKeyboardKey.arrowRight ||
          key == LogicalKeyboardKey.home ||
          key == LogicalKeyboardKey.end ||
          key == LogicalKeyboardKey.pageUp ||
          key == LogicalKeyboardKey.pageDown ||
          key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.tab ||
          key == LogicalKeyboardKey.f2 ||
          key == LogicalKeyboardKey.escape ||
          (key == LogicalKeyboardKey.keyA && isControl) ||
          (key == LogicalKeyboardKey.space && (isControl || isShift));
      return isHandledKey ? KeyEventResult.handled : KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.enter && isControl) {
      setState(() {
        _additionalSelectedCells.add(current);
        _cellSelectionAnchor ??= current;
        _cellSelectionExtent ??= current;
        _selectedCell ??= current;
        _focusedCell = current;
      });
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter) {
      if (_cellEditMode) {
        _exitCellEditMode(commit: true);
        _updateCellSelection(
          rowIndex: current.rowIndex + (isShift ? -1 : 1),
          columnIndex: current.columnIndex,
        );
      } else {
        _updateCellSelection(
          rowIndex: current.rowIndex,
          columnIndex: current.columnIndex,
        );
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.tab) {
      final nextCoordinate = _cellNavigation.nextTabCoordinate(
        current: current,
        rowCount: _visibleRows.length,
        columnCount: _columns.length,
        reverse: isShift,
      );
      if (isShift) {
        _updateCellSelection(
          rowIndex: nextCoordinate.rowIndex,
          columnIndex: nextCoordinate.columnIndex,
          extend: true,
        );
      } else {
        _updateCellFocus(
          rowIndex: nextCoordinate.rowIndex,
          columnIndex: nextCoordinate.columnIndex,
        );
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyA && isControl) {
      if (_visibleRows.isNotEmpty && _columns.isNotEmpty) {
        setState(() {
          _cellSelectionAnchor = const StructuredDataCellCoordinate(
            rowIndex: 0,
            columnIndex: 0,
          );
          _cellSelectionExtent = StructuredDataCellCoordinate(
            rowIndex: _visibleRows.length - 1,
            columnIndex: _columns.length - 1,
          );
          _selectedCell = StructuredDataCellCoordinate(
            rowIndex: _visibleRows.length - 1,
            columnIndex: _columns.length - 1,
          );
          _focusedCell = _selectedCell;
          _additionalSelectedCells.clear();
        });
        _scheduleScrollToRow(_visibleRows.length - 1, context);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.space && (isControl || isShift)) {
      if (isControl) {
        setState(() {
          _cellSelectionAnchor = StructuredDataCellCoordinate(
            rowIndex: 0,
            columnIndex: current.columnIndex,
          );
          _cellSelectionExtent = StructuredDataCellCoordinate(
            rowIndex: _visibleRows.length - 1,
            columnIndex: current.columnIndex,
          );
          _selectedCell = current;
          _focusedCell = current;
          _additionalSelectedCells.clear();
        });
        _scheduleScrollToRow(_visibleRows.length - 1, context);
      } else if (isShift) {
        setState(() {
          _cellSelectionAnchor = StructuredDataCellCoordinate(
            rowIndex: current.rowIndex,
            columnIndex: 0,
          );
          _cellSelectionExtent = StructuredDataCellCoordinate(
            rowIndex: current.rowIndex,
            columnIndex: _columns.length - 1,
          );
          _selectedCell = current;
          _focusedCell = current;
          _additionalSelectedCells.clear();
        });
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.f2) {
      final coordinate = _selectedCell ?? _focusedCell;
      if (coordinate != null) {
        if (_cellEditMode) {
          _exitCellEditMode(commit: true);
        } else {
          _enterCellEditMode(coordinate);
        }
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      final nextRow = isControl
          ? _jumpRow(current.rowIndex, current.columnIndex, -1)
          : current.rowIndex - 1;
      if (isShift) {
        _updateCellSelection(
          rowIndex: nextRow,
          columnIndex: current.columnIndex,
          extend: true,
        );
      } else {
        _updateCellFocus(rowIndex: nextRow, columnIndex: current.columnIndex);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      final nextRow = isControl
          ? _jumpRow(current.rowIndex, current.columnIndex, 1)
          : current.rowIndex + 1;
      if (isShift) {
        _updateCellSelection(
          rowIndex: nextRow,
          columnIndex: current.columnIndex,
          extend: true,
        );
      } else {
        _updateCellFocus(rowIndex: nextRow, columnIndex: current.columnIndex);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      final nextColumn = isControl
          ? _jumpColumn(current.rowIndex, current.columnIndex, -1)
          : current.columnIndex - 1;
      if (isShift) {
        _updateCellSelection(
          rowIndex: current.rowIndex,
          columnIndex: nextColumn,
          extend: true,
        );
      } else {
        _updateCellFocus(rowIndex: current.rowIndex, columnIndex: nextColumn);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      final nextColumn = isControl
          ? _jumpColumn(current.rowIndex, current.columnIndex, 1)
          : current.columnIndex + 1;
      if (isShift) {
        _updateCellSelection(
          rowIndex: current.rowIndex,
          columnIndex: nextColumn,
          extend: true,
        );
      } else {
        _updateCellFocus(rowIndex: current.rowIndex, columnIndex: nextColumn);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.home) {
      if (isControl) {
        if (isShift) {
          _updateCellSelection(rowIndex: 0, columnIndex: 0, extend: true);
        } else {
          _updateCellFocus(rowIndex: 0, columnIndex: 0);
        }
      } else {
        if (isShift) {
          _updateCellSelection(
            rowIndex: current.rowIndex,
            columnIndex: 0,
            extend: true,
          );
        } else {
          _updateCellFocus(rowIndex: current.rowIndex, columnIndex: 0);
        }
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.end) {
      if (isControl) {
        if (isShift) {
          _updateCellSelection(
            rowIndex: _visibleRows.length - 1,
            columnIndex: _columns.length - 1,
            extend: true,
          );
        } else {
          _updateCellFocus(
            rowIndex: _visibleRows.length - 1,
            columnIndex: _columns.length - 1,
          );
        }
      } else {
        if (isShift) {
          _updateCellSelection(
            rowIndex: current.rowIndex,
            columnIndex: _columns.length - 1,
            extend: true,
          );
        } else {
          _updateCellFocus(
            rowIndex: current.rowIndex,
            columnIndex: _columns.length - 1,
          );
        }
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.pageUp) {
      if (isShift) {
        _updateCellSelection(
          rowIndex: current.rowIndex - _pageStep(context),
          columnIndex: current.columnIndex,
          extend: true,
        );
      } else {
        _updateCellFocus(
          rowIndex: current.rowIndex - _pageStep(context),
          columnIndex: current.columnIndex,
        );
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.pageDown) {
      if (isShift) {
        _updateCellSelection(
          rowIndex: current.rowIndex + _pageStep(context),
          columnIndex: current.columnIndex,
          extend: true,
        );
      } else {
        _updateCellFocus(
          rowIndex: current.rowIndex + _pageStep(context),
          columnIndex: current.columnIndex,
        );
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      if (_cellEditMode) {
        _exitCellEditMode(commit: false);
      } else {
        setState(() {
          if (_selectedCell != null) {
            _cellSelectionAnchor = _selectedCell;
            _cellSelectionExtent = _selectedCell;
          }
          _additionalSelectedCells.clear();
        });
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }
}
