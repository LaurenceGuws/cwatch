import 'dart:convert';
import 'dart:ffi' show Pointer;

import 'package:cwatch/model/models/app_settings.dart';
import 'package:cwatch/model/services_infra/zide/zide_terminal_ffi_bridge.dart';

class ZideTerminalPollResult {
  const ZideTerminalPollResult({
    required this.snapshot,
    required this.frame,
    required this.usingNativeScrollback,
  });

  final ZideTerminalSnapshotData snapshot;
  final ZideTerminalFrameData frame;
  final bool usingNativeScrollback;
}

class ZideTerminalSessionController {
  ZideTerminalSessionController._({
    required this.bridge,
    required this.handle,
    required this.libraryPath,
  });

  factory ZideTerminalSessionController.open({
    required AppSettings settings,
    int rows = 18,
    int cols = 72,
    int scrollbackRows = 512,
    int cellWidth = 8,
    int cellHeight = 16,
  }) {
    final bridge = ZideTerminalFfiBridge.open(settings: settings);
    final handle = bridge.create(
      rows: rows,
      cols: cols,
      scrollbackRows: scrollbackRows,
      cursorShape: 0,
      cursorBlink: true,
    );
    bridge.resize(
      handle,
      cols: cols,
      rows: rows,
      cellWidth: cellWidth,
      cellHeight: cellHeight,
    );
    bridge.feedOutput(handle, utf8.encode('\x1b]0;zide-migration\x07'));
    final session = ZideTerminalSessionController._(
      bridge: bridge,
      handle: handle,
      libraryPath: bridge.libraryPath,
    );
    session._rows = rows;
    session._cols = cols;
    return session;
  }

  final ZideTerminalFfiBridge bridge;
  final Pointer<ZideTerminalHandle> handle;
  final String libraryPath;
  bool _shellStarted = false;
  int _rows = 18;
  int _cols = 72;

  bool get shellStarted => _shellStarted;
  int get rows => _rows;
  int get cols => _cols;

  void dispose() {
    bridge.destroy(handle);
  }

  void resize({
    required int rows,
    required int cols,
    required int cellWidth,
    required int cellHeight,
  }) {
    _rows = rows;
    _cols = cols;
    bridge.resize(
      handle,
      cols: cols,
      rows: rows,
      cellWidth: cellWidth,
      cellHeight: cellHeight,
    );
  }

  ZideTerminalPollResult pollFrame() {
    bridge.poll(handle);
    final snapshotPtr = bridge.acquireSnapshot(handle);
    try {
      final snapshot = bridge.readSnapshot(snapshotPtr);
      final usingNativeScrollback = bridge.supportsScrollbackApi;
      final frame = usingNativeScrollback
          ? bridge.snapshotToFrameWithScrollback(handle, snapshotPtr)
          : bridge.snapshotToFrame(snapshotPtr);
      return ZideTerminalPollResult(
        snapshot: snapshot,
        frame: frame,
        usingNativeScrollback: usingNativeScrollback,
      );
    } finally {
      bridge.releaseSnapshot(snapshotPtr);
    }
  }

  ZideTerminalSnapshotData readSnapshotMeta() {
    final snapshotPtr = bridge.acquireSnapshot(handle);
    try {
      return bridge.readSnapshot(snapshotPtr);
    } finally {
      bridge.releaseSnapshot(snapshotPtr);
    }
  }

  String snapshotPlainText() {
    final snapshotPtr = bridge.acquireSnapshot(handle);
    try {
      return bridge.snapshotToPlainText(snapshotPtr);
    } finally {
      bridge.releaseSnapshot(snapshotPtr);
    }
  }

  void startShellIfNeeded() {
    if (_shellStarted) {
      return;
    }
    bridge.start(handle, shell: '/bin/sh');
    _shellStarted = true;
  }

  void sendBytes(List<int> bytes) {
    if (bytes.isEmpty) {
      return;
    }
    bridge.sendBytes(handle, bytes);
  }

  void feedOutput(List<int> bytes) {
    if (bytes.isEmpty) {
      return;
    }
    bridge.feedOutput(handle, bytes);
  }

  bool get supportsMouseApi => bridge.supportsMouseApi;

  void sendMouse({
    required int kind,
    required int button,
    required int row,
    required int col,
    required int pixelX,
    required int pixelY,
    required bool hasPixel,
    required int modifiers,
    required int buttonsDown,
  }) {
    bridge.sendMouse(
      handle,
      kind: kind,
      button: button,
      row: row,
      col: col,
      pixelX: pixelX,
      pixelY: pixelY,
      hasPixel: hasPixel,
      modifiers: modifiers,
      buttonsDown: buttonsDown,
    );
  }
}
