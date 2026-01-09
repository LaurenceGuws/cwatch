import 'package:flutter/widgets.dart';

import 'grid_selection.dart';

/// Keyboard-driven focus + selection manager for grid widgets.
class GridFocusController extends ChangeNotifier {
  GridFocusController({
    this.initialCell = const CellRef(0, 0),
    this.maxRows = 0,
    this.maxCols = 0,
  }) : focusNode = FocusNode(debugLabel: 'grid_focus'),
       _state = GridSelectionState(
         activeCell: initialCell,
         selection: {initialCell},
         anchor: initialCell,
         editMode: false,
       );

  final FocusNode focusNode;
  final CellRef initialCell;

  /// Optional bounds for navigation. 0/negative means unbounded.
  final int maxRows;
  final int maxCols;

  GridSelectionState _state;
  GridSelectionState get state => _state;

  bool get editMode => _state.editMode;
  CellRef get activeCell => _state.activeCell;
  Set<CellRef> get selection => _state.selection;
  CellRef get anchor => _state.anchor;

  /// Sets focus only, leaving any existing selection as-is.
  void focus(CellRef cell) {
    final clamped = _clamp(cell);
    _update(
      GridSelectionState(
        activeCell: clamped,
        selection: selection,
        anchor: anchor,
        editMode: false,
      ),
    );
  }

  /// Selects a single cell and moves focus to it.
  void select(CellRef cell) {
    final clamped = _clamp(cell);
    _update(
      GridSelectionState(
        activeCell: clamped,
        selection: {clamped},
        anchor: clamped,
        editMode: false,
      ),
    );
  }

  void extendSelection(CellRef extent) {
    final clamped = _clamp(extent);
    final base = anchor;
    final range = SelectionRange(anchor: base, extent: clamped);
    _update(
      GridSelectionState(
        activeCell: clamped,
        selection: _cellsInRange(range),
        anchor: base,
        editMode: false,
      ),
    );
  }

  void enterEditMode() {
    if (_state.editMode) return;
    _update(
      GridSelectionState(
        activeCell: activeCell,
        selection: selection,
        anchor: anchor,
        editMode: true,
      ),
    );
  }

  void exitEditMode() {
    if (!_state.editMode) return;
    _update(
      GridSelectionState(
        activeCell: activeCell,
        selection: selection,
        anchor: anchor,
        editMode: false,
      ),
    );
  }

  void moveBy({int dRow = 0, int dCol = 0, bool extend = false}) {
    final next = CellRef(activeCell.row + dRow, activeCell.col + dCol);
    if (extend) {
      extendSelection(next);
    } else {
      focus(next);
    }
  }

  void addSelection(CellRef cell) {
    final clamped = _clamp(cell);
    final nextSet = {...selection, clamped};
    _update(
      GridSelectionState(
        activeCell: clamped,
        selection: nextSet,
        anchor: anchor,
        editMode: false,
      ),
    );
  }

  CellRef jumpEdge({
    required CellRef origin,
    required CellRef delta,
    required bool Function(CellRef cell) hasValue,
  }) {
    CellRef current = origin;
    CellRef next = CellRef(origin.row + delta.row, origin.col + delta.col);
    while (_withinBounds(next) && hasValue(next)) {
      current = next;
      next = CellRef(next.row + delta.row, next.col + delta.col);
    }
    return _clamp(current);
  }

  CellRef _clamp(CellRef cell) {
    final maxRow = maxRows > 0 ? maxRows - 1 : cell.row;
    final maxCol = maxCols > 0 ? maxCols - 1 : cell.col;
    return CellRef(cell.row.clamp(0, maxRow), cell.col.clamp(0, maxCol));
  }

  Set<CellRef> _cellsInRange(SelectionRange range) {
    final cells = <CellRef>{};
    for (var r = range.top; r <= range.bottom; r++) {
      for (var c = range.left; c <= range.right; c++) {
        cells.add(CellRef(r, c));
      }
    }
    return cells;
  }

  CellRef edgeOfRow(int row, {required bool end}) {
    final maxCol = maxCols > 0 ? maxCols - 1 : 0;
    return CellRef(
      row.clamp(0, maxRows > 0 ? maxRows - 1 : row),
      end ? maxCol : 0,
    );
  }

  CellRef edgeOfGrid({required bool bottom, required bool right}) {
    final row = bottom && maxRows > 0 ? maxRows - 1 : 0;
    final col = right && maxCols > 0 ? maxCols - 1 : 0;
    return CellRef(row, col);
  }

  bool _withinBounds(CellRef cell) {
    final maxRow = maxRows > 0 ? maxRows - 1 : cell.row;
    final maxCol = maxCols > 0 ? maxCols - 1 : cell.col;
    return cell.row >= 0 &&
        cell.col >= 0 &&
        cell.row <= maxRow &&
        cell.col <= maxCol;
  }

  void _update(GridSelectionState next) {
    _state = next;
    notifyListeners();
  }

  @override
  void dispose() {
    focusNode.dispose();
    super.dispose();
  }
}
