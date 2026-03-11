import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/view/shared/widgets/data_table/structured_data_table.dart';

void main() {
  const projection = StructuredDataTableProjection<Map<String, Object?>>();

  StructuredDataColumn<Map<String, Object?>> column(
    String label, {
    String Function(Map<String, Object?> row)? autoFitText,
    Comparable<Object?>? Function(Map<String, Object?> row)? sortValue,
  }) {
    return StructuredDataColumn<Map<String, Object?>>(
      label: label,
      cellBuilder: (context, row) => const SizedBox.shrink(),
      autoFitText: autoFitText,
      sortValue: sortValue,
    );
  }

  test('buildVisibleColumns filters hidden ids and preserves first fallback', () {
    final columns = [
      column('Name'),
      column('Status'),
    ];

    final visible = projection.buildVisibleColumns(
      columns: columns,
      hiddenColumnIds: const {'Name', 'Status'},
      columnIdBuilder: null,
    );

    expect(visible.length, 1);
    expect(visible.single.label, 'Name');
  });

  test('applySearch uses explicit row search text builder when present', () {
    final rows = [
      {'name': 'alpha', 'status': 'running'},
      {'name': 'beta', 'status': 'stopped'},
    ];

    final visible = projection.applySearch(
      rows: rows,
      query: 'STOP',
      columns: [column('Name', autoFitText: (row) => '${row['name']}')],
      rowSearchTextBuilder: (row) => '${row['status']}',
    );

    expect(visible, [rows[1]]);
  });

  test('applySearch falls back to searchable columns', () {
    final rows = [
      {'name': 'alpha'},
      {'name': 'beta'},
    ];

    final visible = projection.applySearch(
      rows: rows,
      query: 'alp',
      columns: [column('Name', autoFitText: (row) => '${row['name']}')],
      rowSearchTextBuilder: null,
    );

    expect(visible, [rows[0]]);
  });

  test('sortVisibleRows sorts ascending and descending', () {
    final rows = [
      {'name': 'beta'},
      {'name': 'alpha'},
    ];
    final columns = [
      column('Name', autoFitText: (row) => '${row['name']}'),
    ];

    final ascending = projection.sortVisibleRows(
      rows: rows,
      columns: columns,
      sortColumnIndex: 0,
      sortAscending: true,
    );
    final descending = projection.sortVisibleRows(
      rows: rows,
      columns: columns,
      sortColumnIndex: 0,
      sortAscending: false,
    );

    expect(ascending.map((row) => row['name']).toList(), ['alpha', 'beta']);
    expect(descending.map((row) => row['name']).toList(), ['beta', 'alpha']);
  });

  test('compareNullable orders null after non-null', () {
    expect(projection.compareNullable('a', null), lessThan(0));
    expect(projection.compareNullable(null, 'a'), greaterThan(0));
    expect(projection.compareNullable(null, null), 0);
  });
}
