part of 'structured_data_table.dart';

class StructuredDataTableProjection<T> {
  const StructuredDataTableProjection();

  List<StructuredDataColumn<T>> buildVisibleColumns({
    required List<StructuredDataColumn<T>> columns,
    required Set<String> hiddenColumnIds,
    required String Function(StructuredDataColumn<T> column)? columnIdBuilder,
  }) {
    if (hiddenColumnIds.isEmpty) {
      return List.of(columns);
    }
    final idFor = columnIdBuilder ?? (column) => column.label.trim();
    final visible = <StructuredDataColumn<T>>[];
    for (final column in columns) {
      if (!hiddenColumnIds.contains(idFor(column))) {
        visible.add(column);
      }
    }
    if (visible.isEmpty && columns.isNotEmpty) {
      visible.add(columns.first);
    }
    return visible;
  }

  List<T> applySearch({
    required List<T> rows,
    required String query,
    required List<StructuredDataColumn<T>> columns,
    required String Function(T row)? rowSearchTextBuilder,
  }) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return rows;
    }
    return rows
        .where(
          (row) => rowMatchesQuery(
            row,
            query: normalized,
            columns: columns,
            rowSearchTextBuilder: rowSearchTextBuilder,
          ),
        )
        .toList(growable: false);
  }

  bool rowMatchesQuery(
    T row, {
    required String query,
    required List<StructuredDataColumn<T>> columns,
    required String Function(T row)? rowSearchTextBuilder,
  }) {
    if (rowSearchTextBuilder != null) {
      return rowSearchTextBuilder(row).toLowerCase().contains(query);
    }
    var hasSearchableColumn = false;
    for (final column in columns) {
      final textExtractor = column.autoFitText;
      if (textExtractor == null) {
        continue;
      }
      hasSearchableColumn = true;
      if (textExtractor(row).toLowerCase().contains(query)) {
        return true;
      }
    }
    return !hasSearchableColumn;
  }

  List<T> sortVisibleRows({
    required List<T> rows,
    required List<StructuredDataColumn<T>> columns,
    required int? sortColumnIndex,
    required bool sortAscending,
  }) {
    if (sortColumnIndex == null ||
        sortColumnIndex < 0 ||
        sortColumnIndex >= columns.length) {
      return rows;
    }
    final sortValue = sortValueForColumn(columns, sortColumnIndex);
    if (sortValue == null) {
      return rows;
    }
    final sorted = rows.toList(growable: false);
    sorted.sort((a, b) {
      final av = sortValue(a);
      final bv = sortValue(b);
      final result = compareNullable(av, bv);
      return sortAscending ? result : -result;
    });
    return sorted;
  }

  Comparable<Object?>? Function(T row)? sortValueForColumn(
    List<StructuredDataColumn<T>> columns,
    int index,
  ) {
    if (index < 0 || index >= columns.length) {
      return null;
    }
    final column = columns[index];
    if (column.sortValue != null) {
      return column.sortValue;
    }
    final textExtractor = column.autoFitText;
    if (textExtractor == null) {
      return null;
    }
    return (row) => textExtractor(row).toLowerCase();
  }

  int compareNullable(Comparable<Object?>? a, Comparable<Object?>? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return a.compareTo(b);
  }
}
