import 'package:cwatch/model/services_infra/zide/zide_terminal_ffi_bridge.dart';

class TerminalScrollbackController {
  int _scrollOffsetRows = 0;
  ZideTerminalFrameData? _historyFrame;
  ZideTerminalFrameData _liveFrame = const ZideTerminalFrameData(
    rows: 0,
    viewportRows: 0,
    cols: 0,
    cursorRow: 0,
    cursorCol: 0,
    cursorVisible: false,
    cells: [],
  );

  bool get isLive => _scrollOffsetRows == 0 && _historyFrame == null;

  String modeLabel() {
    if (isLive) {
      return 'live';
    }
    final source = _historyFrame ?? _liveFrame;
    final max = _maxScrollRows(source);
    return 'history(rows=$_scrollOffsetRows/$max)';
  }

  ZideTerminalFrameData effectiveFrame() {
    final source = _historyFrame ?? _liveFrame;
    return _sliceFrame(source, _scrollOffsetRows);
  }

  void updateLiveFrame({required ZideTerminalFrameData frame}) {
    _liveFrame = frame;
    if (_historyFrame != null) {
      return;
    }
    final max = _maxScrollRows(frame);
    if (_scrollOffsetRows > max) {
      _scrollOffsetRows = max;
    }
  }

  void scrollUp({int rows = 1}) {
    if (rows <= 0) {
      return;
    }

    final source = _historyFrame ?? _liveFrame;
    final max = _maxScrollRows(source);
    if (max <= 0) {
      return;
    }

    _historyFrame ??= _liveFrame;
    _scrollOffsetRows = (_scrollOffsetRows + rows).clamp(0, max);
  }

  void scrollDown({int rows = 1}) {
    if (rows <= 0 || isLive) {
      return;
    }

    _scrollOffsetRows = (_scrollOffsetRows - rows).clamp(0, 1 << 30);
    if (_scrollOffsetRows == 0) {
      _historyFrame = null;
    }
  }

  void scrollLive() {
    _historyFrame = null;
    _scrollOffsetRows = 0;
  }

  int _maxScrollRows(ZideTerminalFrameData frame) {
    final viewportRows = frame.viewportRows <= 0
        ? frame.rows
        : frame.viewportRows;
    return (frame.rows - viewportRows).clamp(0, 1 << 30);
  }

  ZideTerminalFrameData _sliceFrame(
    ZideTerminalFrameData source,
    int offsetRows,
  ) {
    if (source.rows <= 0 || source.cols <= 0 || source.cells.isEmpty) {
      return source;
    }

    final viewportRows = source.viewportRows <= 0
        ? source.rows
        : source.viewportRows;
    final clampedViewport = viewportRows.clamp(1, source.rows);
    final maxOffset = _maxScrollRows(source);
    final clampedOffset = offsetRows.clamp(0, maxOffset);
    final startRow = (source.rows - clampedViewport - clampedOffset).clamp(
      0,
      source.rows,
    );
    final startCell = startRow * source.cols;
    final endCell = (startRow + clampedViewport) * source.cols;
    final cells = source.cells.sublist(startCell, endCell);

    final cursorInWindow =
        source.cursorVisible &&
        source.cursorRow >= startRow &&
        source.cursorRow < startRow + clampedViewport;
    final cursorRow = cursorInWindow ? source.cursorRow - startRow : 0;

    return ZideTerminalFrameData(
      rows: clampedViewport,
      viewportRows: clampedViewport,
      cols: source.cols,
      cursorRow: cursorRow,
      cursorCol: source.cursorCol,
      cursorVisible: cursorInWindow,
      cells: cells,
    );
  }
}
