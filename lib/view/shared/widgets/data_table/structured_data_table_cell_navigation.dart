part of 'structured_data_table.dart';

class StructuredDataTableCellNavigation<T> {
  const StructuredDataTableCellNavigation();

  bool cellHasValue({
    required List<T> rows,
    required List<StructuredDataColumn<T>> columns,
    required int rowIndex,
    required int columnIndex,
  }) {
    if (rowIndex < 0 || rowIndex >= rows.length) {
      return false;
    }
    if (columnIndex < 0 || columnIndex >= columns.length) {
      return false;
    }
    final row = rows[rowIndex];
    final column = columns[columnIndex];
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

  int jumpRow({
    required List<T> rows,
    required List<StructuredDataColumn<T>> columns,
    required int startRow,
    required int columnIndex,
    required int delta,
  }) {
    if (rows.isEmpty) return startRow;
    final step = delta.sign;
    if (step == 0) return startRow;
    var row = startRow;
    final currentHasValue = cellHasValue(
      rows: rows,
      columns: columns,
      rowIndex: startRow,
      columnIndex: columnIndex,
    );
    if (currentHasValue) {
      var next = row + step;
      while (next >= 0 &&
          next < rows.length &&
          cellHasValue(
            rows: rows,
            columns: columns,
            rowIndex: next,
            columnIndex: columnIndex,
          )) {
        row = next;
        next += step;
      }
      return row;
    }
    var next = row + step;
    while (next >= 0 &&
        next < rows.length &&
        !cellHasValue(
          rows: rows,
          columns: columns,
          rowIndex: next,
          columnIndex: columnIndex,
        )) {
      row = next;
      next += step;
    }
    if (next >= 0 && next < rows.length) {
      return next;
    }
    return row;
  }

  int jumpColumn({
    required List<T> rows,
    required List<StructuredDataColumn<T>> columns,
    required int rowIndex,
    required int startColumn,
    required int delta,
  }) {
    if (columns.isEmpty) return startColumn;
    final step = delta.sign;
    if (step == 0) return startColumn;
    var column = startColumn;
    final currentHasValue = cellHasValue(
      rows: rows,
      columns: columns,
      rowIndex: rowIndex,
      columnIndex: startColumn,
    );
    if (currentHasValue) {
      var next = column + step;
      while (next >= 0 && next < columns.length) {
        if (!cellHasValue(
          rows: rows,
          columns: columns,
          rowIndex: rowIndex,
          columnIndex: next,
        )) {
          break;
        }
        column = next;
        next += step;
      }
      return column;
    }
    var next = column + step;
    while (next >= 0 && next < columns.length) {
      if (cellHasValue(
        rows: rows,
        columns: columns,
        rowIndex: rowIndex,
        columnIndex: next,
      )) {
        return next;
      }
      column = next;
      next += step;
    }
    return column;
  }

  StructuredDataCellCoordinate nextTabCoordinate({
    required StructuredDataCellCoordinate current,
    required int rowCount,
    required int columnCount,
    required bool reverse,
  }) {
    var nextRow = current.rowIndex;
    var nextColumn = current.columnIndex + (reverse ? -1 : 1);
    if (nextColumn < 0) {
      nextColumn = columnCount - 1;
      nextRow = current.rowIndex - 1;
    } else if (nextColumn >= columnCount) {
      nextColumn = 0;
      nextRow = current.rowIndex + 1;
    }
    return StructuredDataCellCoordinate(
      rowIndex: nextRow.clamp(0, max(0, rowCount - 1)),
      columnIndex: nextColumn.clamp(0, max(0, columnCount - 1)),
    );
  }
}
