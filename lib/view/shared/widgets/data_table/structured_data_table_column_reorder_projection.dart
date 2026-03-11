part of 'structured_data_table.dart';

class StructuredDataTableColumnReorderResult<T> {
  const StructuredDataTableColumnReorderResult({
    required this.columns,
    required this.columnWidthOverrides,
    required this.resetSort,
  });

  final List<StructuredDataColumn<T>> columns;
  final List<double?> columnWidthOverrides;
  final bool resetSort;
}

class StructuredDataTableColumnReorderProjection<T> {
  const StructuredDataTableColumnReorderProjection();

  bool canAcceptDrop({
    required int sourceIndex,
    required int targetIndex,
  }) {
    return sourceIndex != targetIndex;
  }

  StructuredDataTableColumnReorderResult<T> reorder({
    required List<StructuredDataColumn<T>> columns,
    required List<double?> columnWidthOverrides,
    required int fromIndex,
    required int targetIndex,
  }) {
    if (fromIndex == targetIndex ||
        fromIndex < 0 ||
        targetIndex < 0 ||
        fromIndex >= columns.length ||
        targetIndex >= columns.length) {
      return StructuredDataTableColumnReorderResult<T>(
        columns: List<StructuredDataColumn<T>>.from(columns),
        columnWidthOverrides: List<double?>.from(columnWidthOverrides),
        resetSort: false,
      );
    }

    final nextColumns = List<StructuredDataColumn<T>>.from(columns);
    final nextOverrides = List<double?>.from(columnWidthOverrides);
    final movedColumn = nextColumns.removeAt(fromIndex);
    nextColumns.insert(targetIndex, movedColumn);
    final movedWidth = nextOverrides.removeAt(fromIndex);
    nextOverrides.insert(targetIndex, movedWidth);

    return StructuredDataTableColumnReorderResult<T>(
      columns: nextColumns,
      columnWidthOverrides: nextOverrides,
      resetSort: true,
    );
  }
}
