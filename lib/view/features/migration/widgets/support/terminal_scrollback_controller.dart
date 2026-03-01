import 'package:cwatch/model/services_infra/zide/zide_terminal_ffi_bridge.dart';

class TerminalScrollbackController {
  TerminalScrollbackController({this.maxFrames = 400});

  final int maxFrames;

  int _scrollOffsetRows = 0;
  ZideTerminalFrameData? _historyFrame;
  final List<ZideTerminalFrameData> _frames = <ZideTerminalFrameData>[];
  int? _frameAnchorIndex;
  ZideTerminalFrameData _liveFrame = const ZideTerminalFrameData(
    rows: 0,
    viewportRows: 0,
    cols: 0,
    cursorRow: 0,
    cursorCol: 0,
    cursorVisible: false,
    cells: [],
  );

  bool get isLive =>
      _scrollOffsetRows == 0 && _historyFrame == null && _frameAnchorIndex == null;

  String modeLabel() {
    if (_frameAnchorIndex != null) {
      return 'history(frame=${_frameAnchorIndex! + 1}/${_frames.length})';
    }
    if (isLive) {
      return 'live';
    }
    final source = _historyFrame ?? _liveFrame;
    final max = _maxScrollRows(source);
    return 'history(rows=$_scrollOffsetRows/$max)';
  }

  ZideTerminalFrameData effectiveFrame() {
    if (_frameAnchorIndex != null && _frames.isNotEmpty) {
      final index = _frameAnchorIndex!.clamp(0, _frames.length - 1);
      return _frames[index];
    }
    final source = _historyFrame ?? _liveFrame;
    return _sliceFrame(source, _scrollOffsetRows);
  }

  void updateLiveFrame({required ZideTerminalFrameData frame}) {
    _liveFrame = frame;
    final viewportFrame = _sliceFrame(_liveFrame, 0);
    final last = _frames.isEmpty ? null : _frames.last;
    if (last == null || !_sameFrame(last, viewportFrame)) {
      _frames.add(viewportFrame);
      if (_frames.length > maxFrames) {
        _frames.removeAt(0);
        if (_frameAnchorIndex != null) {
          _frameAnchorIndex = (_frameAnchorIndex! - 1).clamp(
            0,
            _frames.length - 1,
          );
        }
      }
    }

    if (!isLive) {
      return;
    }
  }

  void scrollUp({int rows = 1}) {
    final source = _historyFrame ?? _liveFrame;
    final max = _maxScrollRows(source);
    if (rows <= 0) {
      return;
    }
    if (max <= 0) {
      if (_frames.length < 2) {
        return;
      }
      final anchor = _frameAnchorIndex ?? (_frames.length - 1);
      final step = rows.clamp(1, 32);
      _frameAnchorIndex = (anchor - step).clamp(0, _frames.length - 1);
      return;
    }
    _frameAnchorIndex = null;
    _historyFrame ??= _liveFrame;
    _scrollOffsetRows = (_scrollOffsetRows + rows).clamp(0, max);
  }

  void scrollDown({int rows = 1}) {
    if (rows <= 0) {
      return;
    }
    if (_frameAnchorIndex != null) {
      final step = rows.clamp(1, 32);
      final next = (_frameAnchorIndex! + step).clamp(0, _frames.length - 1);
      _frameAnchorIndex = next == _frames.length - 1 ? null : next;
      return;
    }
    if (isLive) {
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
    _frameAnchorIndex = null;
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

  bool _sameFrame(ZideTerminalFrameData a, ZideTerminalFrameData b) {
    if (a.rows != b.rows || a.cols != b.cols || a.cells.length != b.cells.length) {
      return false;
    }
    for (var i = 0; i < a.cells.length; i++) {
      final ac = a.cells[i];
      final bc = b.cells[i];
      if (ac.codepoint != bc.codepoint ||
          ac.width != bc.width ||
          ac.fg.r != bc.fg.r ||
          ac.fg.g != bc.fg.g ||
          ac.fg.b != bc.fg.b ||
          ac.fg.a != bc.fg.a ||
          ac.bg.r != bc.bg.r ||
          ac.bg.g != bc.bg.g ||
          ac.bg.b != bc.bg.b ||
          ac.bg.a != bc.bg.a) {
        return false;
      }
    }
    return true;
  }
}
