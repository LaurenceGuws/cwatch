import 'dart:convert';
import 'dart:ffi' show Pointer;

import 'package:cwatch/model/models/app_settings.dart';
import 'package:cwatch/model/services_infra/zide/zide_terminal_ffi_bridge.dart';

class ZideTerminalPollResult {
  const ZideTerminalPollResult({
    required this.snapshot,
    required this.frame,
  });

  final ZideTerminalSnapshotData snapshot;
  final ZideTerminalFrameData frame;
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
    return ZideTerminalSessionController._(
      bridge: bridge,
      handle: handle,
      libraryPath: bridge.libraryPath,
    );
  }

  final ZideTerminalFfiBridge bridge;
  final Pointer<ZideTerminalHandle> handle;
  final String libraryPath;
  bool _shellStarted = false;

  bool get shellStarted => _shellStarted;

  void dispose() {
    bridge.destroy(handle);
  }

  ZideTerminalPollResult pollFrame() {
    bridge.poll(handle);
    final snapshotPtr = bridge.acquireSnapshot(handle);
    try {
      final snapshot = bridge.readSnapshot(snapshotPtr);
      final frame = bridge.snapshotToFrame(snapshotPtr);
      return ZideTerminalPollResult(snapshot: snapshot, frame: frame);
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
}
