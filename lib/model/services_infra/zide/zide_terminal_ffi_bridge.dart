import 'dart:convert';
import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'package:cwatch/model/models/app_settings.dart';

import 'zide_ffi_backend_config.dart';
import 'zide_ffi_exception.dart';
import 'zide_ffi_log_config.dart';

final class ZideTerminalHandle extends Opaque {}

final class _ZideTerminalCreateConfig extends Struct {
  @Uint16()
  external int rows;

  @Uint16()
  external int cols;

  @Uint32()
  external int scrollbackRows;

  @Uint8()
  external int cursorShape;

  @Uint8()
  external int cursorBlink;
}

final class ZideTerminalColor extends Struct {
  @Uint8()
  external int r;

  @Uint8()
  external int g;

  @Uint8()
  external int b;

  @Uint8()
  external int a;
}

final class ZideTerminalCell extends Struct {
  @Uint32()
  external int codepoint;

  @Uint8()
  external int combiningLen;

  @Uint8()
  external int width;

  @Uint8()
  external int height;

  @Uint8()
  external int x;

  @Uint8()
  external int y;

  @Uint32()
  external int combining0;

  @Uint32()
  external int combining1;

  external ZideTerminalColor fg;
  external ZideTerminalColor bg;
  external ZideTerminalColor underlineColor;

  @Uint8()
  external int bold;

  @Uint8()
  external int blink;

  @Uint8()
  external int blinkFast;

  @Uint8()
  external int reverse;

  @Uint8()
  external int underline;

  @Array(3)
  external Array<Uint8> padding0;

  @Uint32()
  external int linkId;
}

final class ZideTerminalSnapshot extends Struct {
  @Uint32()
  external int abiVersion;

  @Uint32()
  external int structSize;

  @Uint32()
  external int rows;

  @Uint32()
  external int cols;

  @Uint64()
  external int generation;

  @IntPtr()
  external int cellCount;

  external Pointer<ZideTerminalCell> cells;

  @Uint32()
  external int cursorRow;

  @Uint32()
  external int cursorCol;

  @Uint8()
  external int cursorVisible;

  @Uint8()
  external int cursorShape;

  @Uint8()
  external int cursorBlink;

  @Uint8()
  external int altActive;

  @Uint8()
  external int screenReverse;

  @Uint8()
  external int hasDamage;

  @Uint32()
  external int damageStartRow;

  @Uint32()
  external int damageEndRow;

  @Uint32()
  external int damageStartCol;

  @Uint32()
  external int damageEndCol;

  external Pointer<Uint8> titlePtr;

  @IntPtr()
  external int titleLen;

  external Pointer<Uint8> cwdPtr;

  @IntPtr()
  external int cwdLen;

  external Pointer<Void> ctx;
}

final class _ZideTerminalEvent extends Struct {
  @Int32()
  external int kind;

  external Pointer<Uint8> dataPtr;

  @IntPtr()
  external int dataLen;

  @Int32()
  external int int0;

  @Int32()
  external int int1;
}

final class _ZideTerminalEventBuffer extends Struct {
  external Pointer<_ZideTerminalEvent> events;

  @IntPtr()
  external int count;

  external Pointer<Void> ctx;
}

final class _ZideTerminalStringBuffer extends Struct {
  external Pointer<Uint8> ptr;

  @IntPtr()
  external int len;

  external Pointer<Void> ctx;
}

class ZideTerminalChildExitStatusData {
  const ZideTerminalChildExitStatusData({
    required this.code,
    required this.hasStatus,
  });

  final int code;
  final bool hasStatus;
}

class ZideTerminalSnapshotData {
  const ZideTerminalSnapshotData({
    required this.rows,
    required this.cols,
    required this.generation,
    required this.cellCount,
    required this.title,
    required this.cwd,
    required this.cursorRow,
    required this.cursorCol,
    required this.hasDamage,
  });

  final int rows;
  final int cols;
  final int generation;
  final int cellCount;
  final String title;
  final String cwd;
  final int cursorRow;
  final int cursorCol;
  final bool hasDamage;
}

class ZideTerminalEventData {
  const ZideTerminalEventData({
    required this.kind,
    required this.payload,
    required this.int0,
    required this.int1,
  });

  final int kind;
  final List<int> payload;
  final int int0;
  final int int1;
}

class ZideTerminalColorData {
  const ZideTerminalColorData({
    required this.r,
    required this.g,
    required this.b,
    required this.a,
  });

  final int r;
  final int g;
  final int b;
  final int a;
}

class ZideTerminalCellData {
  const ZideTerminalCellData({
    required this.codepoint,
    required this.width,
    required this.fg,
    required this.bg,
  });

  final int codepoint;
  final int width;
  final ZideTerminalColorData fg;
  final ZideTerminalColorData bg;
}

class ZideTerminalFrameData {
  const ZideTerminalFrameData({
    required this.rows,
    required this.cols,
    required this.viewportRows,
    required this.cursorRow,
    required this.cursorCol,
    required this.cursorVisible,
    required this.cells,
  });

  /// Total row count represented by [cells] (`rows * cols` cells expected).
  final int rows;

  /// Viewport row count (visible terminal height).
  final int viewportRows;
  final int cols;
  final int cursorRow;
  final int cursorCol;
  final bool cursorVisible;
  final List<ZideTerminalCellData> cells;
}

class ZideTerminalFfiBridge {
  ZideTerminalFfiBridge._({
    required DynamicLibrary library,
    required this.libraryPath,
  }) : _create = library
           .lookupFunction<
             Int32 Function(
               Pointer<_ZideTerminalCreateConfig>,
               Pointer<Pointer<ZideTerminalHandle>>,
             ),
             int Function(
               Pointer<_ZideTerminalCreateConfig>,
               Pointer<Pointer<ZideTerminalHandle>>,
             )
           >('zide_terminal_create'),
       _destroy = library
           .lookupFunction<
             Void Function(Pointer<ZideTerminalHandle>),
             void Function(Pointer<ZideTerminalHandle>)
           >('zide_terminal_destroy'),
       _poll = library
           .lookupFunction<
             Int32 Function(Pointer<ZideTerminalHandle>),
             int Function(Pointer<ZideTerminalHandle>)
           >('zide_terminal_poll'),
       _start = library
           .lookupFunction<
             Int32 Function(Pointer<ZideTerminalHandle>, Pointer<Utf8>),
             int Function(Pointer<ZideTerminalHandle>, Pointer<Utf8>)
           >('zide_terminal_start'),
       _resize = library
           .lookupFunction<
             Int32 Function(
               Pointer<ZideTerminalHandle>,
               Uint16,
               Uint16,
               Uint16,
               Uint16,
             ),
             int Function(Pointer<ZideTerminalHandle>, int, int, int, int)
           >('zide_terminal_resize'),
       _sendBytes = library
           .lookupFunction<
             Int32 Function(
               Pointer<ZideTerminalHandle>,
               Pointer<Uint8>,
               IntPtr,
             ),
             int Function(Pointer<ZideTerminalHandle>, Pointer<Uint8>, int)
           >('zide_terminal_send_bytes'),
       _feedOutput = library
           .lookupFunction<
             Int32 Function(
               Pointer<ZideTerminalHandle>,
               Pointer<Uint8>,
               IntPtr,
             ),
             int Function(Pointer<ZideTerminalHandle>, Pointer<Uint8>, int)
           >('zide_terminal_feed_output'),
       _snapshotAcquire = library
           .lookupFunction<
             Int32 Function(
               Pointer<ZideTerminalHandle>,
               Pointer<ZideTerminalSnapshot>,
             ),
             int Function(
               Pointer<ZideTerminalHandle>,
               Pointer<ZideTerminalSnapshot>,
             )
           >('zide_terminal_snapshot_acquire'),
       _snapshotRelease = library
           .lookupFunction<
             Void Function(Pointer<ZideTerminalSnapshot>),
             void Function(Pointer<ZideTerminalSnapshot>)
           >('zide_terminal_snapshot_release'),
       _eventDrain = library
           .lookupFunction<
             Int32 Function(
               Pointer<ZideTerminalHandle>,
               Pointer<_ZideTerminalEventBuffer>,
             ),
             int Function(
               Pointer<ZideTerminalHandle>,
               Pointer<_ZideTerminalEventBuffer>,
             )
           >('zide_terminal_event_drain'),
       _eventsFree = library
           .lookupFunction<
             Void Function(Pointer<_ZideTerminalEventBuffer>),
             void Function(Pointer<_ZideTerminalEventBuffer>)
           >('zide_terminal_events_free'),
       _isAlive = library
           .lookupFunction<
             Uint8 Function(Pointer<ZideTerminalHandle>),
             int Function(Pointer<ZideTerminalHandle>)
           >('zide_terminal_is_alive'),
       _currentTitle = library
           .lookupFunction<
             Int32 Function(
               Pointer<ZideTerminalHandle>,
               Pointer<_ZideTerminalStringBuffer>,
             ),
             int Function(
               Pointer<ZideTerminalHandle>,
               Pointer<_ZideTerminalStringBuffer>,
             )
           >('zide_terminal_current_title'),
       _currentCwd = library
           .lookupFunction<
             Int32 Function(
               Pointer<ZideTerminalHandle>,
               Pointer<_ZideTerminalStringBuffer>,
             ),
             int Function(
               Pointer<ZideTerminalHandle>,
               Pointer<_ZideTerminalStringBuffer>,
             )
           >('zide_terminal_current_cwd'),
       _stringFree = library
           .lookupFunction<
             Void Function(Pointer<_ZideTerminalStringBuffer>),
             void Function(Pointer<_ZideTerminalStringBuffer>)
           >('zide_terminal_string_free'),
       _childExitStatus = library
           .lookupFunction<
             Int32 Function(
               Pointer<ZideTerminalHandle>,
               Pointer<Int32>,
               Pointer<Uint8>,
             ),
             int Function(
               Pointer<ZideTerminalHandle>,
               Pointer<Int32>,
               Pointer<Uint8>,
             )
           >('zide_terminal_child_exit_status'),
       _snapshotAbiVersion = library
           .lookupFunction<Uint32 Function(), int Function()>(
             'zide_terminal_snapshot_abi_version',
           ),
       _eventAbiVersion = library
           .lookupFunction<Uint32 Function(), int Function()>(
             'zide_terminal_event_abi_version',
           ),
       _statusString = library
           .lookupFunction<
             Pointer<Utf8> Function(Int32),
             Pointer<Utf8> Function(int)
           >('zide_terminal_status_string');

  factory ZideTerminalFfiBridge.open({
    required AppSettings settings,
    String? overrideLibraryPath,
  }) {
    ZideFfiLogConfig.apply(settings: settings);
    final config = ZideFfiBackendConfig(settings: settings);
    final path = config.resolveTerminalLibraryPath(
      overridePath: overrideLibraryPath,
    );

    try {
      return ZideTerminalFfiBridge._(
        library: DynamicLibrary.open(path),
        libraryPath: path,
      );
    } catch (error) {
      throw ZideFfiException(
        'Failed to open terminal ffi library at "$path": $error',
      );
    }
  }

  final String libraryPath;

  final int Function(
    Pointer<_ZideTerminalCreateConfig>,
    Pointer<Pointer<ZideTerminalHandle>>,
  )
  _create;
  final void Function(Pointer<ZideTerminalHandle>) _destroy;
  final int Function(Pointer<ZideTerminalHandle>) _poll;
  final int Function(Pointer<ZideTerminalHandle>, Pointer<Utf8>) _start;
  final int Function(Pointer<ZideTerminalHandle>, int, int, int, int) _resize;
  final int Function(Pointer<ZideTerminalHandle>, Pointer<Uint8>, int)
  _sendBytes;
  final int Function(Pointer<ZideTerminalHandle>, Pointer<Uint8>, int)
  _feedOutput;
  final int Function(Pointer<ZideTerminalHandle>, Pointer<ZideTerminalSnapshot>)
  _snapshotAcquire;
  final void Function(Pointer<ZideTerminalSnapshot>) _snapshotRelease;
  final int Function(
    Pointer<ZideTerminalHandle>,
    Pointer<_ZideTerminalEventBuffer>,
  )
  _eventDrain;
  final void Function(Pointer<_ZideTerminalEventBuffer>) _eventsFree;
  final int Function(Pointer<ZideTerminalHandle>) _isAlive;
  final int Function(
    Pointer<ZideTerminalHandle>,
    Pointer<_ZideTerminalStringBuffer>,
  )
  _currentTitle;
  final int Function(
    Pointer<ZideTerminalHandle>,
    Pointer<_ZideTerminalStringBuffer>,
  )
  _currentCwd;
  final void Function(Pointer<_ZideTerminalStringBuffer>) _stringFree;
  final int Function(
    Pointer<ZideTerminalHandle>,
    Pointer<Int32>,
    Pointer<Uint8>,
  )
  _childExitStatus;
  final int Function() _snapshotAbiVersion;
  final int Function() _eventAbiVersion;
  final Pointer<Utf8> Function(int) _statusString;

  Pointer<ZideTerminalHandle> create({
    int rows = 24,
    int cols = 80,
    int scrollbackRows = 2000,
    int cursorShape = 0,
    bool cursorBlink = true,
  }) {
    final config = calloc<_ZideTerminalCreateConfig>();
    final outHandle = calloc<Pointer<ZideTerminalHandle>>();
    try {
      config.ref
        ..rows = rows
        ..cols = cols
        ..scrollbackRows = scrollbackRows
        ..cursorShape = cursorShape
        ..cursorBlink = cursorBlink ? 1 : 0;
      _throwIfError(_create(config, outHandle), operation: 'terminal_create');
      final handle = outHandle.value;
      if (handle == nullptr) {
        throw const ZideFfiException('terminal_create returned a null handle');
      }
      return handle;
    } finally {
      calloc.free(outHandle);
      calloc.free(config);
    }
  }

  void destroy(Pointer<ZideTerminalHandle> handle) {
    if (handle == nullptr) {
      return;
    }
    _destroy(handle);
  }

  void poll(Pointer<ZideTerminalHandle> handle) {
    _throwIfError(_poll(handle), operation: 'terminal_poll');
  }

  void start(Pointer<ZideTerminalHandle> handle, {String shell = '/bin/sh'}) {
    final shellUtf8 = shell.toNativeUtf8();
    try {
      _throwIfError(_start(handle, shellUtf8), operation: 'terminal_start');
    } finally {
      calloc.free(shellUtf8);
    }
  }

  void resize(
    Pointer<ZideTerminalHandle> handle, {
    required int cols,
    required int rows,
    int cellWidth = 8,
    int cellHeight = 16,
  }) {
    _throwIfError(
      _resize(handle, cols, rows, cellWidth, cellHeight),
      operation: 'terminal_resize',
    );
  }

  void sendBytes(Pointer<ZideTerminalHandle> handle, List<int> bytes) {
    _withBytes(bytes, (ptr, len) {
      _throwIfError(
        _sendBytes(handle, ptr, len),
        operation: 'terminal_send_bytes',
      );
    });
  }

  void feedOutput(Pointer<ZideTerminalHandle> handle, List<int> bytes) {
    _withBytes(bytes, (ptr, len) {
      _throwIfError(
        _feedOutput(handle, ptr, len),
        operation: 'terminal_feed_output',
      );
    });
  }

  Pointer<ZideTerminalSnapshot> acquireSnapshot(
    Pointer<ZideTerminalHandle> handle,
  ) {
    final snapshot = calloc<ZideTerminalSnapshot>();
    try {
      _throwIfError(
        _snapshotAcquire(handle, snapshot),
        operation: 'terminal_snapshot_acquire',
      );
      return snapshot;
    } catch (_) {
      calloc.free(snapshot);
      rethrow;
    }
  }

  void releaseSnapshot(Pointer<ZideTerminalSnapshot> snapshot) {
    _snapshotRelease(snapshot);
    calloc.free(snapshot);
  }

  ZideTerminalSnapshotData readSnapshot(
    Pointer<ZideTerminalSnapshot> snapshot,
  ) {
    final value = snapshot.ref;
    return ZideTerminalSnapshotData(
      rows: value.rows,
      cols: value.cols,
      generation: value.generation,
      cellCount: value.cellCount,
      title: _decodeUtf8(value.titlePtr, value.titleLen),
      cwd: _decodeUtf8(value.cwdPtr, value.cwdLen),
      cursorRow: value.cursorRow,
      cursorCol: value.cursorCol,
      hasDamage: value.hasDamage != 0,
    );
  }

  String readFirstRow(Pointer<ZideTerminalSnapshot> snapshot) {
    final value = snapshot.ref;
    if (value.cells == nullptr || value.cols <= 0) {
      return '';
    }

    final chars = <String>[];
    for (var col = 0; col < value.cols; col++) {
      final cell = (value.cells + col).ref;
      if (cell.width == 0) {
        continue;
      }
      final codepoint = cell.codepoint;
      chars.add(codepoint == 0 ? ' ' : String.fromCharCode(codepoint));
    }
    return chars.join().trimRight();
  }

  String snapshotToPlainText(Pointer<ZideTerminalSnapshot> snapshot) {
    final value = snapshot.ref;
    if (value.cells == nullptr || value.cols <= 0) {
      return '';
    }
    final totalRows = _snapshotTotalRows(value);
    if (totalRows <= 0) {
      return '';
    }

    final buffer = StringBuffer();
    for (var row = 0; row < totalRows; row++) {
      for (var col = 0; col < value.cols; col++) {
        final index = row * value.cols + col;
        final cell = (value.cells + index).ref;
        if (cell.width == 0) {
          continue;
        }
        final codepoint = cell.codepoint;
        buffer.write(codepoint == 0 ? ' ' : String.fromCharCode(codepoint));
      }
      if (row < totalRows - 1) {
        buffer.writeln();
      }
    }
    return buffer.toString();
  }

  ZideTerminalFrameData snapshotToFrame(
    Pointer<ZideTerminalSnapshot> snapshot,
  ) {
    final value = snapshot.ref;
    final totalRows = _snapshotTotalRows(value);
    final totalCells = totalRows * value.cols;
    if (value.cells == nullptr || totalCells <= 0) {
      return ZideTerminalFrameData(
        rows: totalRows,
        cols: value.cols,
        viewportRows: value.rows,
        cursorRow: value.cursorRow,
        cursorCol: value.cursorCol,
        cursorVisible: value.cursorVisible != 0,
        cells: const [],
      );
    }

    final cells = List<ZideTerminalCellData>.generate(totalCells, (index) {
      final raw = (value.cells + index).ref;
      return ZideTerminalCellData(
        codepoint: raw.codepoint,
        width: raw.width,
        fg: ZideTerminalColorData(
          r: raw.fg.r,
          g: raw.fg.g,
          b: raw.fg.b,
          a: raw.fg.a,
        ),
        bg: ZideTerminalColorData(
          r: raw.bg.r,
          g: raw.bg.g,
          b: raw.bg.b,
          a: raw.bg.a,
        ),
      );
    });

    final viewportStart = (totalRows - value.rows).clamp(0, totalRows);
    final absoluteCursorRow = viewportStart + value.cursorRow;

    return ZideTerminalFrameData(
      rows: totalRows,
      cols: value.cols,
      viewportRows: value.rows,
      cursorRow: absoluteCursorRow,
      cursorCol: value.cursorCol,
      cursorVisible: value.cursorVisible != 0,
      cells: cells,
    );
  }

  int _snapshotTotalRows(ZideTerminalSnapshot value) {
    if (value.cols <= 0) {
      return value.rows;
    }
    final byCount = (value.cellCount ~/ value.cols);
    if (byCount >= value.rows && byCount > 0) {
      return byCount;
    }
    return value.rows;
  }

  List<ZideTerminalEventData> drainEvents(Pointer<ZideTerminalHandle> handle) {
    final buffer = calloc<_ZideTerminalEventBuffer>();
    try {
      _throwIfError(
        _eventDrain(handle, buffer),
        operation: 'terminal_event_drain',
      );
      final count = buffer.ref.count;
      final events = <ZideTerminalEventData>[];
      for (var i = 0; i < count; i++) {
        final raw = (buffer.ref.events + i).ref;
        events.add(
          ZideTerminalEventData(
            kind: raw.kind,
            payload: _readBytes(raw.dataPtr, raw.dataLen),
            int0: raw.int0,
            int1: raw.int1,
          ),
        );
      }
      return events;
    } finally {
      _eventsFree(buffer);
      calloc.free(buffer);
    }
  }

  bool isAlive(Pointer<ZideTerminalHandle> handle) {
    return _isAlive(handle) != 0;
  }

  String currentTitle(Pointer<ZideTerminalHandle> handle) {
    return _currentString(
      operation: 'terminal_current_title',
      call: (buffer) => _currentTitle(handle, buffer),
    );
  }

  String currentCwd(Pointer<ZideTerminalHandle> handle) {
    return _currentString(
      operation: 'terminal_current_cwd',
      call: (buffer) => _currentCwd(handle, buffer),
    );
  }

  ZideTerminalChildExitStatusData childExitStatus(
    Pointer<ZideTerminalHandle> handle,
  ) {
    final code = calloc<Int32>();
    final hasStatus = calloc<Uint8>();
    try {
      _throwIfError(
        _childExitStatus(handle, code, hasStatus),
        operation: 'terminal_child_exit_status',
      );
      return ZideTerminalChildExitStatusData(
        code: code.value,
        hasStatus: hasStatus.value != 0,
      );
    } finally {
      calloc.free(code);
      calloc.free(hasStatus);
    }
  }

  int snapshotAbiVersion() => _snapshotAbiVersion();

  int eventAbiVersion() => _eventAbiVersion();

  String statusString(int status) {
    final pointer = _statusString(status);
    if (pointer == nullptr) {
      return 'unknown';
    }
    return pointer.toDartString();
  }

  void _throwIfError(int status, {required String operation}) {
    if (status == 0) {
      return;
    }
    throw ZideFfiException(
      '$operation failed with status=$status (${statusString(status)})',
    );
  }

  String _currentString({
    required String operation,
    required int Function(Pointer<_ZideTerminalStringBuffer>) call,
  }) {
    final buffer = calloc<_ZideTerminalStringBuffer>();
    try {
      _throwIfError(call(buffer), operation: operation);
      return _decodeUtf8(buffer.ref.ptr, buffer.ref.len);
    } finally {
      _stringFree(buffer);
      calloc.free(buffer);
    }
  }

  static String _decodeUtf8(Pointer<Uint8> ptr, int len) {
    if (ptr == nullptr || len <= 0) {
      return '';
    }
    return utf8.decode(_readBytes(ptr, len), allowMalformed: true);
  }

  static List<int> _readBytes(Pointer<Uint8> ptr, int len) {
    if (ptr == nullptr || len <= 0) {
      return const [];
    }
    return List<int>.of(ptr.asTypedList(len));
  }

  static void _withBytes(
    List<int> bytes,
    void Function(Pointer<Uint8> ptr, int len) callback,
  ) {
    if (bytes.isEmpty) {
      callback(nullptr, 0);
      return;
    }

    final ptr = calloc<Uint8>(bytes.length);
    try {
      ptr.asTypedList(bytes.length).setAll(0, bytes);
      callback(ptr, bytes.length);
    } finally {
      calloc.free(ptr);
    }
  }
}
