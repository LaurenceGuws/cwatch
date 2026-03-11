import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/view/shared/widgets/data_table/structured_data_table.dart';

void main() {
  const state = StructuredDataTableCellSelectionState();

  test('clampCoordinate bounds row and column to visible grid', () {
    expect(
      state.clampCoordinate(
        rowIndex: -1,
        columnIndex: 9,
        rowCount: 3,
        columnCount: 4,
      ),
      const StructuredDataCellCoordinate(rowIndex: 0, columnIndex: 3),
    );
  });

  test('updateSelection resets anchor/extent and clears additional cells', () {
    final next = state.updateSelection(
      current: StructuredDataTableCellSelectionSnapshot(
        selectedCell: StructuredDataCellCoordinate(rowIndex: 0, columnIndex: 0),
        focusedCell: StructuredDataCellCoordinate(rowIndex: 0, columnIndex: 0),
        anchor: StructuredDataCellCoordinate(rowIndex: 0, columnIndex: 0),
        extent: StructuredDataCellCoordinate(rowIndex: 1, columnIndex: 1),
        additionalSelectedCells: {
          StructuredDataCellCoordinate(rowIndex: 2, columnIndex: 2),
        },
      ),
      coordinate: const StructuredDataCellCoordinate(rowIndex: 1, columnIndex: 2),
      extend: false,
    );

    expect(next.selectedCell, const StructuredDataCellCoordinate(rowIndex: 1, columnIndex: 2));
    expect(next.anchor, const StructuredDataCellCoordinate(rowIndex: 1, columnIndex: 2));
    expect(next.extent, const StructuredDataCellCoordinate(rowIndex: 1, columnIndex: 2));
    expect(next.additionalSelectedCells, isEmpty);
  });

  test('updateSelection with extend preserves anchor and advances extent', () {
    final next = state.updateSelection(
      current: const StructuredDataTableCellSelectionSnapshot(
        selectedCell: StructuredDataCellCoordinate(rowIndex: 0, columnIndex: 0),
        focusedCell: StructuredDataCellCoordinate(rowIndex: 0, columnIndex: 0),
        anchor: StructuredDataCellCoordinate(rowIndex: 0, columnIndex: 0),
        extent: StructuredDataCellCoordinate(rowIndex: 0, columnIndex: 0),
      ),
      coordinate: const StructuredDataCellCoordinate(rowIndex: 2, columnIndex: 1),
      extend: true,
    );

    expect(next.anchor, const StructuredDataCellCoordinate(rowIndex: 0, columnIndex: 0));
    expect(next.extent, const StructuredDataCellCoordinate(rowIndex: 2, columnIndex: 1));
  });

  test('isCellSelected respects range and additional selected cells', () {
    final snapshot = StructuredDataTableCellSelectionSnapshot(
      selectedCell: StructuredDataCellCoordinate(rowIndex: 2, columnIndex: 1),
      anchor: StructuredDataCellCoordinate(rowIndex: 0, columnIndex: 0),
      extent: StructuredDataCellCoordinate(rowIndex: 2, columnIndex: 1),
      additionalSelectedCells: {
        StructuredDataCellCoordinate(rowIndex: 4, columnIndex: 4),
      },
    );

    expect(
      state.isCellSelected(current: snapshot, rowIndex: 1, columnIndex: 1),
      isTrue,
    );
    expect(
      state.isCellSelected(current: snapshot, rowIndex: 4, columnIndex: 4),
      isTrue,
    );
    expect(
      state.isCellSelected(current: snapshot, rowIndex: 3, columnIndex: 3),
      isFalse,
    );
  });
}
