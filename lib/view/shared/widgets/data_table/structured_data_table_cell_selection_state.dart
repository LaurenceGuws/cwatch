part of 'structured_data_table.dart';

class StructuredDataTableCellSelectionSnapshot {
  const StructuredDataTableCellSelectionSnapshot({
    this.selectedCell,
    this.focusedCell,
    this.anchor,
    this.extent,
    this.additionalSelectedCells = const <StructuredDataCellCoordinate>{},
  });

  final StructuredDataCellCoordinate? selectedCell;
  final StructuredDataCellCoordinate? focusedCell;
  final StructuredDataCellCoordinate? anchor;
  final StructuredDataCellCoordinate? extent;
  final Set<StructuredDataCellCoordinate> additionalSelectedCells;
}

class StructuredDataTableCellSelectionState {
  const StructuredDataTableCellSelectionState();

  StructuredDataCellCoordinate clampCoordinate({
    required int rowIndex,
    required int columnIndex,
    required int rowCount,
    required int columnCount,
  }) {
    return StructuredDataCellCoordinate(
      rowIndex: rowIndex.clamp(0, rowCount - 1),
      columnIndex: columnIndex.clamp(0, columnCount - 1),
    );
  }

  StructuredDataTableCellSelectionSnapshot updateSelection({
    required StructuredDataTableCellSelectionSnapshot current,
    required StructuredDataCellCoordinate coordinate,
    required bool extend,
  }) {
    if (extend) {
      return StructuredDataTableCellSelectionSnapshot(
        selectedCell: coordinate,
        focusedCell: coordinate,
        anchor: current.anchor ?? current.extent ?? coordinate,
        extent: coordinate,
        additionalSelectedCells: current.additionalSelectedCells,
      );
    }
    return StructuredDataTableCellSelectionSnapshot(
      selectedCell: coordinate,
      focusedCell: coordinate,
      anchor: coordinate,
      extent: coordinate,
      additionalSelectedCells: const <StructuredDataCellCoordinate>{},
    );
  }

  StructuredDataTableCellSelectionSnapshot beginMarquee({
    required StructuredDataCellCoordinate coordinate,
  }) {
    return StructuredDataTableCellSelectionSnapshot(
      selectedCell: coordinate,
      focusedCell: coordinate,
      anchor: coordinate,
      extent: coordinate,
      additionalSelectedCells: const <StructuredDataCellCoordinate>{},
    );
  }

  StructuredDataTableCellSelectionSnapshot updateFocus({
    required StructuredDataTableCellSelectionSnapshot current,
    required StructuredDataCellCoordinate coordinate,
  }) {
    return StructuredDataTableCellSelectionSnapshot(
      selectedCell: current.selectedCell,
      focusedCell: coordinate,
      anchor: current.anchor,
      extent: current.extent,
      additionalSelectedCells: current.additionalSelectedCells,
    );
  }

  bool isCellSelected({
    required StructuredDataTableCellSelectionSnapshot current,
    required int rowIndex,
    required int columnIndex,
  }) {
    if (current.additionalSelectedCells.contains(
      StructuredDataCellCoordinate(rowIndex: rowIndex, columnIndex: columnIndex),
    )) {
      return true;
    }
    final anchor = current.anchor;
    final extent = current.extent ?? current.selectedCell;
    if (anchor == null || extent == null) {
      return false;
    }
    final top = min(anchor.rowIndex, extent.rowIndex);
    final bottom = max(anchor.rowIndex, extent.rowIndex);
    final left = min(anchor.columnIndex, extent.columnIndex);
    final right = max(anchor.columnIndex, extent.columnIndex);
    return rowIndex >= top &&
        rowIndex <= bottom &&
        columnIndex >= left &&
        columnIndex <= right;
  }
}
