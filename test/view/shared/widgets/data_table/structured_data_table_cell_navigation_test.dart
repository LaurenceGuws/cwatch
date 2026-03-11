import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/view/shared/widgets/data_table/structured_data_table.dart';

void main() {
  final navigation = StructuredDataTableCellNavigation<_Row>();

  const rows = <_Row>[
    _Row(name: 'alpha', count: 1, empty: ''),
    _Row(name: 'bravo', count: null, empty: ''),
    _Row(name: 'charlie', count: 3, empty: ''),
  ];

  final columns = <StructuredDataColumn<_Row>>[
    StructuredDataColumn<_Row>(
      label: 'Name',
      cellBuilder: _emptyCell,
      autoFitText: (row) => row.name,
    ),
    StructuredDataColumn<_Row>(
      label: 'Count',
      cellBuilder: _emptyCell,
      sortValue: (row) => row.count,
    ),
    StructuredDataColumn<_Row>(
      label: 'Empty',
      cellBuilder: _emptyCell,
      autoFitText: (row) => row.empty,
    ),
  ];

  test('cellHasValue respects empty text and null sort values', () {
    expect(
      navigation.cellHasValue(
        rows: rows,
        columns: columns,
        rowIndex: 0,
        columnIndex: 0,
      ),
      isTrue,
    );
    expect(
      navigation.cellHasValue(
        rows: rows,
        columns: columns,
        rowIndex: 1,
        columnIndex: 1,
      ),
      isFalse,
    );
    expect(
      navigation.cellHasValue(
        rows: rows,
        columns: columns,
        rowIndex: 0,
        columnIndex: 2,
      ),
      isFalse,
    );
  });

  test('jumpRow skips contiguous valued rows in same column', () {
    expect(
      navigation.jumpRow(
        rows: rows,
        columns: columns,
        startRow: 0,
        columnIndex: 0,
        delta: 1,
      ),
      2,
    );
  });

  test('jumpColumn jumps to next valued column when current cell is empty', () {
    expect(
      navigation.jumpColumn(
        rows: rows,
        columns: columns,
        rowIndex: 1,
        startColumn: 1,
        delta: -1,
      ),
      0,
    );
  });

  test('nextTabCoordinate wraps across row boundaries and clamps edges', () {
    expect(
      navigation.nextTabCoordinate(
        current: const StructuredDataCellCoordinate(rowIndex: 0, columnIndex: 2),
        rowCount: 3,
        columnCount: 3,
        reverse: false,
      ),
      const StructuredDataCellCoordinate(rowIndex: 1, columnIndex: 0),
    );
    expect(
      navigation.nextTabCoordinate(
        current: const StructuredDataCellCoordinate(rowIndex: 0, columnIndex: 0),
        rowCount: 3,
        columnCount: 3,
        reverse: true,
      ),
      const StructuredDataCellCoordinate(rowIndex: 0, columnIndex: 2),
    );
  });
}

class _Row {
  const _Row({
    required this.name,
    required this.count,
    required this.empty,
  });

  final String name;
  final int? count;
  final String empty;
}

Widget _emptyCell(BuildContext context, _Row row) => const SizedBox.shrink();
