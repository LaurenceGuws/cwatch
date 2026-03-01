import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/model/services_infra/zide/zide_terminal_ffi_bridge.dart';
import 'package:cwatch/view/features/migration/widgets/support/terminal_scrollback_controller.dart';

ZideTerminalFrameData _frame(int rows, int cols, int cursorRow, int cursorCol) {
  return ZideTerminalFrameData(
    rows: rows,
    cols: cols,
    cursorRow: cursorRow,
    cursorCol: cursorCol,
    cursorVisible: true,
    cells: const [],
  );
}

void main() {
  test('stays pinned while scrolled up and live frames continue', () {
    final controller = TerminalScrollbackController(maxFrames: 16);
    controller.updateLiveFrame(generation: 1, frame: _frame(10, 10, 0, 0));
    controller.updateLiveFrame(generation: 2, frame: _frame(10, 10, 1, 0));
    controller.updateLiveFrame(generation: 3, frame: _frame(10, 10, 2, 0));

    controller.scrollUp();
    final pinned = controller.effectiveFrame();
    expect(controller.modeLabel().startsWith('history('), isTrue);

    controller.updateLiveFrame(generation: 4, frame: _frame(10, 10, 3, 0));
    controller.updateLiveFrame(generation: 5, frame: _frame(10, 10, 4, 0));

    final afterUpdates = controller.effectiveFrame();
    expect(afterUpdates.cursorRow, pinned.cursorRow);
    expect(afterUpdates.cursorCol, pinned.cursorCol);
  });

  test('returns to live tail when scrolling down to end', () {
    final controller = TerminalScrollbackController(maxFrames: 16);
    controller.updateLiveFrame(generation: 1, frame: _frame(10, 10, 0, 0));
    controller.updateLiveFrame(generation: 2, frame: _frame(10, 10, 1, 0));
    controller.updateLiveFrame(generation: 3, frame: _frame(10, 10, 2, 0));

    controller.scrollUp();
    controller.scrollDown();
    expect(controller.modeLabel(), 'live');

    controller.updateLiveFrame(generation: 4, frame: _frame(10, 10, 3, 0));
    expect(controller.effectiveFrame().cursorRow, 3);
  });

  test('keeps valid anchor when old frames are trimmed', () {
    final controller = TerminalScrollbackController(maxFrames: 3);
    controller.updateLiveFrame(generation: 1, frame: _frame(10, 10, 0, 0));
    controller.updateLiveFrame(generation: 2, frame: _frame(10, 10, 1, 0));
    controller.updateLiveFrame(generation: 3, frame: _frame(10, 10, 2, 0));
    controller.scrollUp();
    expect(controller.modeLabel().startsWith('history('), isTrue);

    controller.updateLiveFrame(generation: 4, frame: _frame(10, 10, 3, 0));
    controller.scrollLive();
    expect(controller.modeLabel(), 'live');
    expect(controller.effectiveFrame().cursorRow, 3);
  });
}
