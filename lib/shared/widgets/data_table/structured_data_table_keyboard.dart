// ignore_for_file: annotate_overrides
part of 'structured_data_table.dart';

mixin _StructuredDataTableKeyboard<T> on _StructuredDataTableStateBase<T> {
  bool _cellHasValue(int rowIndex, int columnIndex) {
    if (rowIndex < 0 || rowIndex >= _visibleRows.length) {
      return false;
    }
    if (columnIndex < 0 || columnIndex >= _columns.length) {
      return false;
    }
    final row = _visibleRows[rowIndex];
    final column = _columns[columnIndex];
    final textExtractor = column.autoFitText;
    if (textExtractor != null) {
      return textExtractor(row).trim().isNotEmpty;
    }
    final sortValue = column.sortValue;
    if (sortValue != null) {
      final value = sortValue(row);
      if (value == null) return false;
      if (value is String) return value.trim().isNotEmpty;
      return true;
    }
    return true;
  }

  int _jumpRow(int startRow, int columnIndex, int delta) {
    if (_visibleRows.isEmpty) return startRow;
    final step = delta.sign;
    if (step == 0) return startRow;
    var row = startRow;
    final currentHasValue = _cellHasValue(startRow, columnIndex);
    if (currentHasValue) {
      var next = row + step;
      while (next >= 0 &&
          next < _visibleRows.length &&
          _cellHasValue(next, columnIndex)) {
        row = next;
        next += step;
      }
      return row;
    }
    var next = row + step;
    while (next >= 0 &&
        next < _visibleRows.length &&
        !_cellHasValue(next, columnIndex)) {
      row = next;
      next += step;
    }
    if (next >= 0 && next < _visibleRows.length) {
      return next;
    }
    return row;
  }

  int _jumpColumn(int rowIndex, int startColumn, int delta) {
    if (_columns.isEmpty) return startColumn;
    final step = delta.sign;
    if (step == 0) return startColumn;
    var col = startColumn;
    final currentHasValue = _cellHasValue(rowIndex, startColumn);
    if (currentHasValue) {
      var next = col + step;
      while (next >= 0 && next < _columns.length) {
        if (!_cellHasValue(rowIndex, next)) {
          break;
        }
        col = next;
        next += step;
      }
      return col;
    }
    var next = col + step;
    while (next >= 0 && next < _columns.length) {
      if (_cellHasValue(rowIndex, next)) {
        return next;
      }
      col = next;
      next += step;
    }
    return col;
  }

  KeyEventResult _handleCellKeyEvent(FocusNode node, KeyEvent event) {
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
      final delta = isShift ? -1 : 1;
      var nextRow = current.rowIndex;
      var nextColumn = current.columnIndex + delta;
      if (nextColumn < 0) {
        nextColumn = _columns.length - 1;
        nextRow = current.rowIndex - 1;
      } else if (nextColumn >= _columns.length) {
        nextColumn = 0;
        nextRow = current.rowIndex + 1;
      }
      if (isShift) {
        _updateCellSelection(
          rowIndex: nextRow,
          columnIndex: nextColumn,
          extend: true,
        );
      } else {
        _updateCellFocus(rowIndex: nextRow, columnIndex: nextColumn);
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
        _scheduleScrollToRow(_visibleRows.length - 1);
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
        _scheduleScrollToRow(_visibleRows.length - 1);
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
          rowIndex: current.rowIndex - _pageStep(),
          columnIndex: current.columnIndex,
          extend: true,
        );
      } else {
        _updateCellFocus(
          rowIndex: current.rowIndex - _pageStep(),
          columnIndex: current.columnIndex,
        );
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.pageDown) {
      if (isShift) {
        _updateCellSelection(
          rowIndex: current.rowIndex + _pageStep(),
          columnIndex: current.columnIndex,
          extend: true,
        );
      } else {
        _updateCellFocus(
          rowIndex: current.rowIndex + _pageStep(),
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
