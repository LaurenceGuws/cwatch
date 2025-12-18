import 'package:flutter/foundation.dart';

/// Identifier for a single cell.
@immutable
class CellRef {
  const CellRef(this.row, this.col);

  final int row;
  final int col;

  @override
  bool operator ==(Object other) {
    return other is CellRef && other.row == row && other.col == col;
  }

  @override
  int get hashCode => Object.hash(row, col);

  @override
  String toString() => 'CellRef(row=$row, col=$col)';
}

/// Rectangular selection defined by anchor and extent.
@immutable
class SelectionRange {
  const SelectionRange({required this.anchor, required this.extent});

  final CellRef anchor;
  final CellRef extent;

  int get top => anchor.row < extent.row ? anchor.row : extent.row;
  int get bottom => anchor.row > extent.row ? anchor.row : extent.row;
  int get left => anchor.col < extent.col ? anchor.col : extent.col;
  int get right => anchor.col > extent.col ? anchor.col : extent.col;

  bool contains(CellRef cell) {
    return cell.row >= top &&
        cell.row <= bottom &&
        cell.col >= left &&
        cell.col <= right;
  }

  SelectionRange withExtent(CellRef next) =>
      SelectionRange(anchor: anchor, extent: next);
}

/// Selection state emitted to renderers.
@immutable
class GridSelectionState {
  const GridSelectionState({
    required this.activeCell,
    required this.selection,
    required this.anchor,
    required this.editMode,
  });

  final CellRef activeCell;
  final Set<CellRef> selection;
  final CellRef anchor;
  final bool editMode;
}
