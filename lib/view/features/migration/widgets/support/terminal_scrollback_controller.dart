import 'dart:math' as math;

import 'package:cwatch/model/services_infra/zide/zide_terminal_ffi_bridge.dart';

class TerminalScrollbackController {
  TerminalScrollbackController({this.maxFrames = 400});

  final int maxFrames;

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

  // Fallback scrollback for backends that only expose viewport rows.
  final List<String> _fallbackLines = <String>[];
  List<String> _lastViewportLines = const <String>[];

  bool get isLive => _scrollOffsetRows == 0 && _historyFrame == null;

  String modeLabel() {
    if (isLive) {
      return 'live';
    }

    if (_usesFallback(_liveFrame)) {
      final max = _fallbackMaxScrollRows();
      return 'history(lines=$_scrollOffsetRows/$max)';
    }

    final source = _historyFrame ?? _liveFrame;
    final max = _maxScrollRows(source);
    return 'history(rows=$_scrollOffsetRows/$max)';
  }

  ZideTerminalFrameData effectiveFrame() {
    if (isLive) {
      return _sliceFrame(_liveFrame, 0);
    }

    if (_usesFallback(_liveFrame)) {
      return _fallbackSliceFrame(_scrollOffsetRows);
    }

    final source = _historyFrame ?? _liveFrame;
    return _sliceFrame(source, _scrollOffsetRows);
  }

  void updateLiveFrame({required ZideTerminalFrameData frame}) {
    _liveFrame = frame;
    if (_usesFallback(frame)) {
      _ingestFallbackViewport(_sliceFrame(frame, 0));
      if (_scrollOffsetRows > _fallbackMaxScrollRows()) {
        _scrollOffsetRows = _fallbackMaxScrollRows();
      }
    }
    if (!isLive) {
      return;
    }
  }

  void scrollUp({int rows = 1}) {
    if (rows <= 0) {
      return;
    }

    if (_usesFallback(_liveFrame)) {
      final max = _fallbackMaxScrollRows();
      if (max <= 0) {
        return;
      }
      _scrollOffsetRows = (_scrollOffsetRows + rows).clamp(0, max);
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

  bool _usesFallback(ZideTerminalFrameData frame) {
    return _maxScrollRows(frame) <= 0;
  }

  int _fallbackMaxScrollRows() {
    final viewportRows = _liveFrame.viewportRows <= 0
        ? _liveFrame.rows
        : _liveFrame.viewportRows;
    return (_fallbackLines.length - viewportRows).clamp(0, 1 << 30);
  }

  void _ingestFallbackViewport(ZideTerminalFrameData viewportFrame) {
    if (viewportFrame.rows <= 0 || viewportFrame.cols <= 0) {
      return;
    }

    final lines = _frameToLines(viewportFrame);
    if (_fallbackLines.isEmpty) {
      _fallbackLines.addAll(lines);
      _lastViewportLines = lines;
      return;
    }

    var overlap = math.min(_lastViewportLines.length, lines.length);
    while (overlap > 0) {
      var matches = true;
      for (var i = 0; i < overlap; i++) {
        final a = _lastViewportLines[_lastViewportLines.length - overlap + i];
        final b = lines[i];
        if (a != b) {
          matches = false;
          break;
        }
      }
      if (matches) {
        break;
      }
      overlap--;
    }

    _fallbackLines.addAll(lines.skip(overlap));
    _lastViewportLines = lines;

    final maxFallbackLines = math.max(1200, maxFrames * 8);
    if (_fallbackLines.length > maxFallbackLines) {
      final removeCount = _fallbackLines.length - maxFallbackLines;
      _fallbackLines.removeRange(0, removeCount);
    }
  }

  ZideTerminalFrameData _fallbackSliceFrame(int offsetRows) {
    final cols = _liveFrame.cols;
    final viewportRows = _liveFrame.viewportRows <= 0
        ? _liveFrame.rows
        : _liveFrame.viewportRows;

    if (cols <= 0 || viewportRows <= 0 || _fallbackLines.isEmpty) {
      return _sliceFrame(_liveFrame, 0);
    }

    final maxOffset = _fallbackMaxScrollRows();
    final clampedOffset = offsetRows.clamp(0, maxOffset);
    final start = (_fallbackLines.length - viewportRows - clampedOffset).clamp(
      0,
      _fallbackLines.length,
    );

    final lines = <String>[];
    for (var i = 0; i < viewportRows; i++) {
      final index = start + i;
      lines.add(index < _fallbackLines.length ? _fallbackLines[index] : '');
    }

    const fg = ZideTerminalColorData(r: 221, g: 221, b: 221, a: 255);
    const bg = ZideTerminalColorData(r: 0, g: 0, b: 0, a: 255);

    final cells = <ZideTerminalCellData>[];
    for (final rawLine in lines) {
      final padded = rawLine.padRight(cols);
      final line = padded.length > cols ? padded.substring(0, cols) : padded;
      for (var col = 0; col < cols; col++) {
        final codepoint = line.codeUnitAt(col);
        cells.add(
          ZideTerminalCellData(
            codepoint: codepoint,
            width: 1,
            fg: fg,
            bg: bg,
          ),
        );
      }
    }

    return ZideTerminalFrameData(
      rows: viewportRows,
      viewportRows: viewportRows,
      cols: cols,
      cursorRow: 0,
      cursorCol: 0,
      cursorVisible: false,
      cells: cells,
    );
  }

  int _maxScrollRows(ZideTerminalFrameData frame) {
    final viewportRows = frame.viewportRows <= 0 ? frame.rows : frame.viewportRows;
    return (frame.rows - viewportRows).clamp(0, 1 << 30);
  }

  ZideTerminalFrameData _sliceFrame(ZideTerminalFrameData source, int offsetRows) {
    if (source.rows <= 0 || source.cols <= 0 || source.cells.isEmpty) {
      return source;
    }
    final viewportRows = source.viewportRows <= 0 ? source.rows : source.viewportRows;
    final clampedViewport = viewportRows.clamp(1, source.rows);
    final maxOffset = _maxScrollRows(source);
    final clampedOffset = offsetRows.clamp(0, maxOffset);
    final startRow = (source.rows - clampedViewport - clampedOffset).clamp(0, source.rows);
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

  List<String> _frameToLines(ZideTerminalFrameData frame) {
    final lines = <String>[];
    for (var row = 0; row < frame.rows; row++) {
      final chars = StringBuffer();
      for (var col = 0; col < frame.cols; col++) {
        final index = row * frame.cols + col;
        if (index >= frame.cells.length) {
          continue;
        }
        final cell = frame.cells[index];
        if (cell.width == 0) {
          continue;
        }
        final codepoint = cell.codepoint;
        if (codepoint == 0 || codepoint < 32) {
          chars.write(' ');
        } else {
          chars.write(String.fromCharCode(codepoint));
        }
      }
      lines.add(chars.toString().trimRight());
    }
    return lines;
  }
}
