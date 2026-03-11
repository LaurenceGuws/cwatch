import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/view/shared/widgets/data_table/structured_data_table.dart';

void main() {
  group('StructuredDataTableScrollScheduleState', () {
    test('coalesces row targets and clears scheduled flag on flush', () {
      var state = const StructuredDataTableScrollScheduleState();
      state = state.queueRow(2);
      expect(state.pendingRow, 2);
      expect(state.rowScheduled, isFalse);

      state = state.markRowScheduled();
      expect(state.rowScheduled, isTrue);

      state = state.queueRow(5);
      final flush = state.flushRow();
      expect(flush.target, 5);
      expect(flush.nextState.pendingRow, isNull);
      expect(flush.nextState.rowScheduled, isFalse);
    });

    test('coalesces column targets independently from rows', () {
      var state = const StructuredDataTableScrollScheduleState();
      state = state.queueRow(3).markRowScheduled();
      state = state.queueColumn(1).markColumnScheduled();
      state = state.queueColumn(4);

      final columnFlush = state.flushColumn();
      expect(columnFlush.target, 4);
      expect(columnFlush.nextState.columnScheduled, isFalse);
      expect(columnFlush.nextState.pendingColumn, isNull);
      expect(columnFlush.nextState.pendingRow, 3);
      expect(columnFlush.nextState.rowScheduled, isTrue);
    });

    test('row flush preserves independent column state', () {
      var state = const StructuredDataTableScrollScheduleState();
      state = state.queueRow(7).markRowScheduled();
      state = state.queueColumn(2).markColumnScheduled();

      final rowFlush = state.flushRow();
      expect(rowFlush.target, 7);
      expect(rowFlush.nextState.pendingRow, isNull);
      expect(rowFlush.nextState.rowScheduled, isFalse);
      expect(rowFlush.nextState.pendingColumn, 2);
      expect(rowFlush.nextState.columnScheduled, isTrue);
    });
  });
}
