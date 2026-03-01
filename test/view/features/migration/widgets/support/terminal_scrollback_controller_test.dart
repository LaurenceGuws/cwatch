import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/model/services_infra/zide/zide_terminal_ffi_bridge.dart';
import 'package:cwatch/view/features/migration/widgets/support/terminal_scrollback_controller.dart';

ZideTerminalCellData _cell(int codepoint) {
  const color = ZideTerminalColorData(r: 255, g: 255, b: 255, a: 255);
  return ZideTerminalCellData(
    codepoint: codepoint,
    width: 1,
    fg: color,
    bg: color,
  );
}

ZideTerminalFrameData _frame({
  required int totalRows,
  required int viewportRows,
  required int cols,
  required int cursorRow,
  required int cursorCol,
  int seed = 0,
}) {
  final cells = List<ZideTerminalCellData>.generate(
    totalRows * cols,
    (index) => _cell(65 + ((index + seed) % 26)),
  );
  return ZideTerminalFrameData(
    rows: totalRows,
    viewportRows: viewportRows,
    cols: cols,
    cursorRow: cursorRow,
    cursorCol: cursorCol,
    cursorVisible: true,
    cells: cells,
  );
}

void main() {
  test('live frame defaults to viewport rows at tail', () {
    final controller = TerminalScrollbackController();
    controller.updateLiveFrame(
      frame: _frame(
        totalRows: 10,
        viewportRows: 4,
        cols: 3,
        cursorRow: 9,
        cursorCol: 1,
      ),
    );

    final frame = controller.effectiveFrame();
    expect(controller.modeLabel(), 'live');
    expect(frame.rows, 4);
    expect(frame.viewportRows, 4);
    expect(frame.cells.length, 12);
    expect(frame.cursorVisible, isTrue);
    expect(frame.cursorRow, 3);
  });

  test('scroll up moves window into history rows', () {
    final controller = TerminalScrollbackController();
    controller.updateLiveFrame(
      frame: _frame(
        totalRows: 10,
        viewportRows: 4,
        cols: 3,
        cursorRow: 9,
        cursorCol: 0,
      ),
    );

    controller.scrollUp(rows: 2);
    final frame = controller.effectiveFrame();
    expect(controller.modeLabel(), 'history(rows=2/6)');
    expect(frame.rows, 4);
    expect(frame.cells.length, 12);
    // Cursor is no longer in this window.
    expect(frame.cursorVisible, isFalse);
  });

  test('scroll down returns to live mode at offset zero', () {
    final controller = TerminalScrollbackController();
    controller.updateLiveFrame(
      frame: _frame(
        totalRows: 8,
        viewportRows: 4,
        cols: 2,
        cursorRow: 7,
        cursorCol: 0,
      ),
    );
    controller.scrollUp(rows: 3);
    expect(controller.modeLabel().startsWith('history('), isTrue);

    controller.scrollDown(rows: 3);
    expect(controller.modeLabel(), 'live');
    final frame = controller.effectiveFrame();
    expect(frame.rows, 4);
    expect(frame.cursorVisible, isTrue);
    expect(frame.cursorRow, 3);
  });

  test('pinned history remains stable while live frames advance', () {
    final controller = TerminalScrollbackController();
    controller.updateLiveFrame(
      frame: _frame(
        totalRows: 12,
        viewportRows: 4,
        cols: 2,
        cursorRow: 11,
        cursorCol: 0,
      ),
    );
    controller.scrollUp(rows: 4);
    final pinned = controller.effectiveFrame();

    controller.updateLiveFrame(
      frame: _frame(
        totalRows: 14,
        viewportRows: 4,
        cols: 2,
        cursorRow: 13,
        cursorCol: 0,
      ),
    );
    final after = controller.effectiveFrame();
    expect(after.cells.first.codepoint, pinned.cells.first.codepoint);
    expect(after.cells.last.codepoint, pinned.cells.last.codepoint);
    expect(controller.modeLabel(), 'history(rows=4/8)');
  });

  test('falls back to frame history when no row scrollback is available', () {
    final controller = TerminalScrollbackController(maxFrames: 8);
    controller.updateLiveFrame(
      frame: _frame(
        totalRows: 4,
        viewportRows: 4,
        cols: 2,
        cursorRow: 3,
        cursorCol: 0,
        seed: 0,
      ),
    );
    controller.updateLiveFrame(
      frame: _frame(
        totalRows: 4,
        viewportRows: 4,
        cols: 2,
        cursorRow: 2,
        cursorCol: 0,
        seed: 1,
      ),
    );

    controller.scrollUp(rows: 2);
    expect(controller.modeLabel().startsWith('history(frame='), isTrue);
    final history = controller.effectiveFrame();
    expect(history.rows, 4);
    expect(history.viewportRows, 4);
  });

  test('deduplicates identical fallback frames to reduce noisy timeline', () {
    final controller = TerminalScrollbackController(maxFrames: 8);
    final frame = _frame(
      totalRows: 4,
      viewportRows: 4,
      cols: 2,
      cursorRow: 3,
      cursorCol: 0,
    );
    controller.updateLiveFrame(frame: frame);
    controller.updateLiveFrame(frame: frame);
    controller.scrollUp(rows: 3);
    // Only one distinct frame is stored; fallback history cannot move.
    expect(controller.modeLabel(), 'live');
  });
}
