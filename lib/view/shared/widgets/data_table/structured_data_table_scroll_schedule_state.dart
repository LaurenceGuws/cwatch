part of 'structured_data_table.dart';

class StructuredDataTableScrollScheduleState {
  const StructuredDataTableScrollScheduleState({
    this.pendingRow,
    this.rowScheduled = false,
    this.pendingColumn,
    this.columnScheduled = false,
  });

  final int? pendingRow;
  final bool rowScheduled;
  final int? pendingColumn;
  final bool columnScheduled;

  StructuredDataTableScrollScheduleState queueRow(int rowIndex) {
    return StructuredDataTableScrollScheduleState(
      pendingRow: rowIndex,
      rowScheduled: rowScheduled,
      pendingColumn: pendingColumn,
      columnScheduled: columnScheduled,
    );
  }

  StructuredDataTableScrollScheduleState markRowScheduled() {
    return StructuredDataTableScrollScheduleState(
      pendingRow: pendingRow,
      rowScheduled: true,
      pendingColumn: pendingColumn,
      columnScheduled: columnScheduled,
    );
  }

  StructuredDataTableScrollScheduleFlush<int> flushRow() {
    return StructuredDataTableScrollScheduleFlush<int>(
      target: pendingRow,
      nextState: StructuredDataTableScrollScheduleState(
        pendingColumn: pendingColumn,
        columnScheduled: columnScheduled,
      ),
    );
  }

  StructuredDataTableScrollScheduleState queueColumn(int columnIndex) {
    return StructuredDataTableScrollScheduleState(
      pendingRow: pendingRow,
      rowScheduled: rowScheduled,
      pendingColumn: columnIndex,
      columnScheduled: columnScheduled,
    );
  }

  StructuredDataTableScrollScheduleState markColumnScheduled() {
    return StructuredDataTableScrollScheduleState(
      pendingRow: pendingRow,
      rowScheduled: rowScheduled,
      pendingColumn: pendingColumn,
      columnScheduled: true,
    );
  }

  StructuredDataTableScrollScheduleFlush<int> flushColumn() {
    return StructuredDataTableScrollScheduleFlush<int>(
      target: pendingColumn,
      nextState: StructuredDataTableScrollScheduleState(
        pendingRow: pendingRow,
        rowScheduled: rowScheduled,
      ),
    );
  }
}

class StructuredDataTableScrollScheduleFlush<T> {
  const StructuredDataTableScrollScheduleFlush({
    required this.target,
    required this.nextState,
  });

  final T? target;
  final StructuredDataTableScrollScheduleState nextState;
}
