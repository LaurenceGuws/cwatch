import 'package:cwatch/model/services_infra/zide/zide_terminal_ffi_bridge.dart';

class TerminalScrollbackController {
  TerminalScrollbackController({this.maxFrames = 400});

  final int maxFrames;

  final List<ZideTerminalFrameData> _frames = <ZideTerminalFrameData>[];
  int _lastGeneration = -1;
  int? _anchorIndex;
  ZideTerminalFrameData _liveFrame = const ZideTerminalFrameData(
    rows: 0,
    cols: 0,
    cursorRow: 0,
    cursorCol: 0,
    cursorVisible: false,
    cells: [],
  );

  bool get isLive => _anchorIndex == null;

  String modeLabel() {
    if (_anchorIndex == null) {
      return 'live';
    }
    return 'history(${_anchorIndex! + 1}/${_frames.length})';
  }

  ZideTerminalFrameData effectiveFrame() {
    if (_anchorIndex == null || _frames.isEmpty) {
      return _liveFrame;
    }
    final index = _anchorIndex!.clamp(0, _frames.length - 1);
    return _frames[index];
  }

  void updateLiveFrame({
    required int generation,
    required ZideTerminalFrameData frame,
  }) {
    _liveFrame = frame;
    if (_anchorIndex != null) {
      return;
    }
    if (generation == _lastGeneration) {
      return;
    }
    _lastGeneration = generation;
    _frames.add(frame);
    if (_frames.length > maxFrames) {
      _frames.removeAt(0);
      if (_anchorIndex != null) {
        _anchorIndex = (_anchorIndex! - 1).clamp(0, _frames.length - 1);
      }
    }
  }

  void scrollUp() {
    if (_frames.length < 2) {
      return;
    }
    final anchor = _anchorIndex ?? (_frames.length - 1);
    _anchorIndex = (anchor - 1).clamp(0, _frames.length - 1);
  }

  void scrollDown() {
    if (_anchorIndex == null) {
      return;
    }
    final next = (_anchorIndex! + 1).clamp(0, _frames.length - 1);
    _anchorIndex = next == _frames.length - 1 ? null : next;
  }

  void scrollLive() {
    _anchorIndex = null;
  }
}
