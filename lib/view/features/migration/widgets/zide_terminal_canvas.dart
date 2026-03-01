import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

import 'package:cwatch/model/services_infra/logging/app_logger.dart';
import 'package:cwatch/model/services_infra/settings/app_settings_controller.dart';
import 'package:cwatch/model/services_infra/zide/zide_terminal_ffi_bridge.dart';
import 'support/overlay_scrollbar.dart';
import 'support/zide_font_defaults.dart';
import 'support/terminal_paint_layout.dart';
import 'support/terminal_paint_runs.dart';
import 'support/terminal_scrollback_controller.dart';
import 'support/zide_terminal_session_controller.dart';

class ZideTerminalCanvas extends StatefulWidget {
  const ZideTerminalCanvas({
    super.key,
    required this.settingsController,
    this.onPointerHoverChanged,
  });

  final AppSettingsController settingsController;
  final ValueChanged<bool>? onPointerHoverChanged;

  @override
  State<ZideTerminalCanvas> createState() => _ZideTerminalCanvasState();
}

class _ZideTerminalCanvasState extends State<ZideTerminalCanvas> {
  static const String _logTag = 'ZideMigrationTerminal';
  static const int _modelCellWidthPx = 8;
  static const int _modelCellHeightPx = 16;
  ZideTerminalSessionController? _session;
  Timer? _timer;
  final FocusNode _focusNode = FocusNode(debugLabel: 'zide_terminal_canvas');
  late final TextEditingController _commandController;

  String _status = 'Initializing terminal...';
  String _commandRunStatus = 'command runner: idle';
  bool _commandRunning = false;
  bool _followLiveOnInput = true;
  bool _wheelScrollRequiresFocus = false;
  bool _altScreenActive = false;
  final Map<int, int> _glyphClassFlagsCache = <int, int>{};
  final TerminalScrollbackController _scrollback =
      TerminalScrollbackController();
  int _pendingWheelHistoryRowsDelta = 0;
  bool _wheelHistoryFrameScheduled = false;
  int _wheelEventsSinceLog = 0;
  int _wheelFlushesSinceLog = 0;
  int _wheelRowsAppliedSinceLog = 0;
  int _wheelLastLogMs = 0;
  int _lastViewportRows = 0;
  int _lastViewportCols = 0;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
    _commandController = TextEditingController(
      text: "printf '[{ts}] hello-from-pty\\n'",
    );
    _initTerminal();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _commandController.dispose();
    _session?.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    AppLogger().debug(
      'focus=${_focusNode.hasFocus} mode=${_scrollback.modeLabel()}',
      tag: _logTag,
    );
  }

  void _initTerminal() {
    try {
      final session = ZideTerminalSessionController.open(
        settings: widget.settingsController.settings,
      );
      _session = session;
      _status = 'Connected: ${session.libraryPath}';
      _refresh();
      _timer = Timer.periodic(const Duration(milliseconds: 66), (_) {
        _refresh();
      });
      setState(() {});
    } catch (error) {
      setState(() {
        _status = 'Terminal unavailable: $error';
      });
    }
  }

  void _refresh() {
    final session = _session;
    if (session == null) {
      return;
    }

    try {
      final poll = session.pollFrame();
      final meta = poll.snapshot;
      final frame = poll.frame;
      _scrollback.updateLiveFrame(frame: frame);
      if (!mounted) {
        return;
      }
      setState(() {
        _altScreenActive = meta.altActive;
        final mode = _scrollback.modeLabel();
        final scrollbackBackend = poll.usingNativeScrollback
            ? 'native'
            : 'fallback';
        final rendererMeta = session.bridge.supportsRendererMetadataApi
            ? 'meta'
            : 'heuristic';
        _status =
            'rows=${meta.rows} total_rows=${frame.rows} cols=${meta.cols} '
            'title=${meta.title.isEmpty ? '(none)' : meta.title} '
            'alt=${meta.altActive ? 'on' : 'off'} '
            'scrollback=$scrollbackBackend renderer=$rendererMeta mode=$mode';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _status = 'Refresh failed: $error';
      });
    }
  }

  ZideTerminalFrameData get _effectiveFrame {
    return _scrollback.effectiveFrame();
  }

  void _historyUp({int rows = 1}) {
    final before = _scrollback.modeLabel();
    setState(() {
      _scrollback.scrollUp(rows: rows);
    });
    AppLogger().debug(
      'scrollUp rows=$rows mode="$before" -> "${_scrollback.modeLabel()}"',
      tag: _logTag,
    );
  }

  void _historyDown({int rows = 1}) {
    final before = _scrollback.modeLabel();
    setState(() {
      _scrollback.scrollDown(rows: rows);
    });
    AppLogger().debug(
      'scrollDown rows=$rows mode="$before" -> "${_scrollback.modeLabel()}"',
      tag: _logTag,
    );
  }

  void _historyLive() {
    setState(() {
      _scrollback.scrollLive();
    });
  }

  void _historyTop() {
    final before = _scrollback.modeLabel();
    setState(() {
      _scrollback.scrollTop();
    });
    AppLogger().debug(
      'scrollTop mode="$before" -> "${_scrollback.modeLabel()}"',
      tag: _logTag,
    );
  }

  void _setHistoryOffsetRows(int rows) {
    final before = _scrollback.modeLabel();
    setState(() {
      _scrollback.setScrollOffsetRows(rows);
    });
    AppLogger().debug(
      'scrollOverlaySet rows=$rows mode="$before" -> "${_scrollback.modeLabel()}"',
      tag: _logTag,
    );
  }

  void _queueWheelHistoryDelta(int rowsDelta) {
    if (rowsDelta == 0) {
      return;
    }
    _wheelEventsSinceLog++;
    _pendingWheelHistoryRowsDelta += rowsDelta;
    _maybeLogWheelPerf();
    if (_wheelHistoryFrameScheduled) {
      return;
    }
    _wheelHistoryFrameScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _wheelHistoryFrameScheduled = false;
      final delta = _pendingWheelHistoryRowsDelta;
      _pendingWheelHistoryRowsDelta = 0;
      if (!mounted || delta == 0) {
        return;
      }
      _wheelFlushesSinceLog++;
      _wheelRowsAppliedSinceLog += delta.abs();
      final before = _scrollback.modeLabel();
      setState(() {
        if (delta > 0) {
          _scrollback.scrollUp(rows: delta);
        } else {
          _scrollback.scrollDown(rows: -delta);
        }
      });
      AppLogger().debug(
        'scrollWheelFrame rows_delta=$delta mode="$before" -> "${_scrollback.modeLabel()}"',
        tag: _logTag,
      );
      _maybeLogWheelPerf();
    });
  }

  void _maybeLogWheelPerf() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_wheelLastLogMs == 0) {
      _wheelLastLogMs = now;
      return;
    }
    if (now - _wheelLastLogMs < 1000) {
      return;
    }
    if (_wheelEventsSinceLog == 0 &&
        _wheelFlushesSinceLog == 0 &&
        _wheelRowsAppliedSinceLog == 0) {
      _wheelLastLogMs = now;
      return;
    }
    AppLogger().debug(
      'wheelPerf events=$_wheelEventsSinceLog flushes=$_wheelFlushesSinceLog '
      'rowsApplied=$_wheelRowsAppliedSinceLog pendingRows=$_pendingWheelHistoryRowsDelta '
      'frameScheduled=$_wheelHistoryFrameScheduled',
      tag: _logTag,
    );
    AppLogger.emitPerformanceSample(
      source: 'zide_terminal',
      metric: 'wheel_events_per_sec',
      value: _wheelEventsSinceLog.toDouble(),
      attributes: {
        'flushes': _wheelFlushesSinceLog,
        'rows_applied': _wheelRowsAppliedSinceLog,
      },
    );
    AppLogger.emitPerformanceSample(
      source: 'zide_terminal',
      metric: 'wheel_rows_per_sec',
      value: _wheelRowsAppliedSinceLog.toDouble(),
      attributes: {'events': _wheelEventsSinceLog},
    );
    _wheelEventsSinceLog = 0;
    _wheelFlushesSinceLog = 0;
    _wheelRowsAppliedSinceLog = 0;
    _wheelLastLogMs = now;
  }

  Future<void> _copyVisible() async {
    final frame = _effectiveFrame;
    final text = _frameToPlainText(frame);
    await Clipboard.setData(ClipboardData(text: text));
  }

  Future<void> _pasteClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text ?? '';
    if (text.isEmpty) {
      return;
    }
    _sendBytes(utf8.encode(text));
  }

  String _frameToPlainText(ZideTerminalFrameData frame) {
    if (frame.rows <= 0 || frame.cols <= 0 || frame.cells.isEmpty) {
      return '';
    }
    final buffer = StringBuffer();
    for (var row = 0; row < frame.rows; row++) {
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
          buffer.write(' ');
        } else {
          buffer.write(String.fromCharCode(codepoint));
        }
      }
      if (row < frame.rows - 1) {
        buffer.writeln();
      }
    }
    return buffer.toString().trimRight();
  }

  void _sendBytes(List<int> bytes) {
    final session = _session;
    if (session == null || bytes.isEmpty) {
      return;
    }
    try {
      _ensureShellStarted();
      if (_followLiveOnInput && !_scrollback.isLive) {
        _scrollback.scrollLive();
        if (mounted) {
          setState(() {});
        }
        AppLogger().debug(
          'input while history pinned -> forced live tail',
          tag: _logTag,
        );
      }
      session.sendBytes(bytes);
    } catch (_) {
      // For feed-only sessions sendBytes may be ignored by backend, which is
      // acceptable in this prototype widget.
    }
  }

  void _ensureShellStarted() {
    final session = _session;
    if (session == null || session.shellStarted) {
      return;
    }
    session.startShellIfNeeded();
    _commandRunStatus = 'command runner: shell started (interactive)';
  }

  void _syncTerminalViewport(Size size) {
    final session = _session;
    if (session == null) {
      return;
    }
    final cols = (size.width / _modelCellWidthPx).floor().clamp(20, 800);
    final rows = (size.height / _modelCellHeightPx).floor().clamp(6, 400);
    if (cols == _lastViewportCols && rows == _lastViewportRows) {
      return;
    }
    _lastViewportCols = cols;
    _lastViewportRows = rows;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final active = _session;
      if (!mounted || active == null) {
        return;
      }
      active.resize(
        rows: rows,
        cols: cols,
        cellWidth: _modelCellWidthPx,
        cellHeight: _modelCellHeightPx,
      );
      AppLogger().debug('viewport resize rows=$rows cols=$cols', tag: _logTag);
      _refresh();
    });
  }

  Future<void> _runShellCommand() async {
    final session = _session;
    if (session == null || _commandRunning) {
      return;
    }

    final commandTemplate = _commandController.text.trim();
    final runStamp = DateTime.now().toIso8601String();
    final command = commandTemplate.replaceAll('{ts}', runStamp);
    if (command.isEmpty) {
      setState(() {
        _commandRunStatus = 'command runner: empty command';
      });
      return;
    }

    final marker = 'CWATCH_CMD_DONE_${DateTime.now().microsecondsSinceEpoch}';
    final payload = "\r$command; printf '$marker\\n'\n";

    setState(() {
      _commandRunning = true;
      _commandRunStatus = 'command runner: running';
    });

    try {
      _ensureShellStarted();
      // Let the shell render first prompt before injecting command bytes.
      for (var i = 0; i < 12; i++) {
        session.pollFrame();
        await Future<void>.delayed(const Duration(milliseconds: 15));
      }

      session.sendBytes(utf8.encode(payload));

      var sawMarker = false;
      for (var i = 0; i < 80; i++) {
        session.pollFrame();
        final text = session.snapshotPlainText();
        if (text.contains(marker)) {
          sawMarker = true;
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 15));
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _commandRunStatus = sawMarker
            ? 'command runner: PASS marker observed'
            : 'command runner: FAIL marker not observed';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _commandRunStatus = 'command runner error: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _commandRunning = false;
        });
      }
    }
  }

  bool _onKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) {
      return false;
    }
    AppLogger().debug(
      'key down key=${event.logicalKey.keyLabel} focus=${_focusNode.hasFocus} mode=${_scrollback.modeLabel()}',
      tag: _logTag,
    );
    if (_handleHistoryShortcut(event)) {
      return true;
    }
    _ensureShellStarted();

    final logical = event.logicalKey;
    if (logical == LogicalKeyboardKey.enter) {
      _sendBytes(const [13]);
      return true;
    }
    if (logical == LogicalKeyboardKey.backspace) {
      _sendBytes(const [127]);
      return true;
    }
    if (logical == LogicalKeyboardKey.tab) {
      _sendBytes(const [9]);
      return true;
    }
    if (logical == LogicalKeyboardKey.arrowUp) {
      _sendBytes(const [27, 91, 65]);
      return true;
    }
    if (logical == LogicalKeyboardKey.arrowDown) {
      _sendBytes(const [27, 91, 66]);
      return true;
    }
    if (logical == LogicalKeyboardKey.arrowRight) {
      _sendBytes(const [27, 91, 67]);
      return true;
    }
    if (logical == LogicalKeyboardKey.arrowLeft) {
      _sendBytes(const [27, 91, 68]);
      return true;
    }

    final character = event.character;
    if (character == null || character.isEmpty) {
      return false;
    }

    if (HardwareKeyboard.instance.isControlPressed && character.length == 1) {
      final codeUnit = character.toUpperCase().codeUnitAt(0);
      if (codeUnit >= 65 && codeUnit <= 90) {
        _sendBytes([codeUnit - 64]);
        return true;
      }
    }

    _sendBytes(utf8.encode(character));
    return true;
  }

  bool _handleHistoryShortcut(KeyDownEvent event) {
    final logical = event.logicalKey;
    final keyboard = HardwareKeyboard.instance;
    final shift = keyboard.isShiftPressed;
    final control = keyboard.isControlPressed;
    final pageRows = (_effectiveFrame.rows > 0) ? _effectiveFrame.rows : 12;

    if (shift && logical == LogicalKeyboardKey.pageUp) {
      _historyUp(rows: pageRows);
      return true;
    }
    if (shift && logical == LogicalKeyboardKey.pageDown) {
      _historyDown(rows: pageRows);
      return true;
    }
    if (control && logical == LogicalKeyboardKey.home) {
      _historyTop();
      return true;
    }
    if (control && logical == LogicalKeyboardKey.end) {
      _historyLive();
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compactHeader = constraints.maxHeight < 320;
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF111111),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(8),
                  ),
                  border: Border(
                    bottom: BorderSide(color: scheme.outlineVariant),
                  ),
                ),
                child: compactHeader
                    ? Text(
                        _status,
                        style: ZideFontDefaults.applyTo(
                          const TextStyle(
                            color: Color(0xFFDDDDDD),
                            fontSize: 12,
                          ),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _status,
                            style: ZideFontDefaults.applyTo(
                              const TextStyle(
                                color: Color(0xFFDDDDDD),
                                fontSize: 12,
                              ),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton(
                                onPressed: _copyVisible,
                                child: const Text('Copy visible'),
                              ),
                              OutlinedButton(
                                onPressed: _pasteClipboard,
                                child: const Text('Paste clipboard'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Switch(
                                value: _followLiveOnInput,
                                onChanged: (value) {
                                  setState(() {
                                    _followLiveOnInput = value;
                                  });
                                  AppLogger().debug(
                                    'followLiveOnInput=$value',
                                    tag: _logTag,
                                  );
                                },
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Follow live on input (jump to tail when typing while viewing history)',
                                  style: TextStyle(fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Switch(
                                value: _wheelScrollRequiresFocus,
                                onChanged: (value) {
                                  setState(() {
                                    _wheelScrollRequiresFocus = value;
                                  });
                                  AppLogger().debug(
                                    'wheelScrollRequiresFocus=$value',
                                    tag: _logTag,
                                  );
                                },
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Wheel scroll requires terminal focus',
                                  style: TextStyle(fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _commandController,
                                  style: ZideFontDefaults.applyTo(
                                    const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFFDDDDDD),
                                    ),
                                  ),
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                    labelText: 'PTY command',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton(
                                onPressed: _commandRunning
                                    ? null
                                    : _runShellCommand,
                                child: const Text('Run command'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _commandRunStatus,
                            style: ZideFontDefaults.applyTo(
                              const TextStyle(
                                color: Color(0xFFC9C9C9),
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
              Expanded(
                child: Focus(
                  focusNode: _focusNode,
                  onKeyEvent: (_, event) {
                    return _onKeyEvent(event)
                        ? KeyEventResult.handled
                        : KeyEventResult.ignored;
                  },
                  child: Listener(
                    onPointerSignal: (signal) {
                      if (signal is PointerScrollEvent) {
                        if (_wheelScrollRequiresFocus && !_focusNode.hasFocus) {
                          return;
                        }
                        final dy = signal.scrollDelta.dy;
                        final steps = (dy.abs() / 24.0).ceil().clamp(1, 8);
                        final rows = steps * 3;
                        if (dy < 0) {
                          _queueWheelHistoryDelta(rows);
                        } else if (dy > 0) {
                          _queueWheelHistoryDelta(-rows);
                        }
                      }
                    },
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final viewport = Size(
                          constraints.maxWidth,
                          constraints.maxHeight,
                        );
                        _syncTerminalViewport(viewport);
                        final hasScrollableHistory =
                            _scrollback.totalRows > _scrollback.viewportRows;
                        final showOverlayScrollbar =
                            !_altScreenActive && hasScrollableHistory;
                        return Stack(
                          children: [
                            Positioned.fill(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  _focusNode.requestFocus();
                                  _ensureShellStarted();
                                  _refresh();
                                },
                                child: MouseRegion(
                                  onEnter: (_) =>
                                      widget.onPointerHoverChanged?.call(true),
                                  onExit: (_) =>
                                      widget.onPointerHoverChanged?.call(false),
                                  child: CustomPaint(
                                    painter: _ZideTerminalPainter(
                                      frame: _effectiveFrame,
                                      glyphClassLookup: _glyphClassFlagsFor,
                                    ),
                                    child: const SizedBox.expand(),
                                  ),
                                ),
                              ),
                            ),
                            if (showOverlayScrollbar)
                              Positioned(
                                right: 0,
                                top: 0,
                                bottom: 0,
                                child: OverlayScrollbar(
                                  viewportExtent:
                                      (_scrollback.viewportRows > 0
                                              ? _scrollback.viewportRows
                                              : 1)
                                          .toDouble(),
                                  contentExtent:
                                      (_scrollback.totalRows > 0
                                              ? _scrollback.totalRows
                                              : 1)
                                          .toDouble(),
                                  offset: _scrollback.currentScrollRows
                                      .toDouble(),
                                  onOffsetChanged: (value) =>
                                      _setHistoryOffsetRows(value.round()),
                                  onStepUp: () => _historyUp(
                                    rows: (_effectiveFrame.rows > 0)
                                        ? _effectiveFrame.rows
                                        : 12,
                                  ),
                                  onStepDown: () => _historyDown(
                                    rows: (_effectiveFrame.rows > 0)
                                        ? _effectiveFrame.rows
                                        : 12,
                                  ),
                                  reverse: true,
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  int _glyphClassFlagsFor(int codepoint) {
    final cached = _glyphClassFlagsCache[codepoint];
    if (cached != null) {
      return cached;
    }
    final session = _session;
    if (session == null || !session.bridge.supportsRendererMetadataApi) {
      _glyphClassFlagsCache[codepoint] = 0;
      return 0;
    }
    try {
      final metadata = session.bridge.rendererMetadata(codepoint);
      final flags = metadata?.glyphClassFlags ?? 0;
      _glyphClassFlagsCache[codepoint] = flags;
      return flags;
    } catch (_) {
      _glyphClassFlagsCache[codepoint] = 0;
      return 0;
    }
  }
}

class _ZideTerminalPainter extends CustomPainter {
  _ZideTerminalPainter({required this.frame, required this.glyphClassLookup});

  final ZideTerminalFrameData frame;
  final int Function(int codepoint) glyphClassLookup;
  static const double _modelCellWidth = 8;
  static const double _modelCellHeight = 16;
  static const int _boxDrawStart = 0x2500;
  static const int _gridCharEnd = 0x259F;
  static const int _boxDrawHardEnd = 0x254B;

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFF000000);
    canvas.drawRect(Offset.zero & size, bgPaint);

    if (frame.rows <= 0 || frame.cols <= 0 || frame.cells.isEmpty) {
      return;
    }

    final layout = TerminalPaintLayout.compute(
      size: size,
      rows: frame.rows,
      cols: frame.cols,
      modelCellWidth: _modelCellWidth,
      modelCellHeight: _modelCellHeight,
    );
    final cellWidth = layout.cellWidth;
    final cellHeight = layout.cellHeight;
    final gridBounds = Rect.fromLTWH(
      layout.originX,
      layout.originY,
      layout.gridWidth,
      layout.gridHeight,
    );

    final cellPaint = Paint()..isAntiAlias = false;
    final glyphStyle = ZideFontDefaults.applyTo(
      TextStyle(fontSize: cellHeight * 0.78, height: 1.0),
    );
    final glyphCache = <int, TextPainter>{};
    canvas.save();
    canvas.clipRect(gridBounds);
    for (var row = 0; row < frame.rows; row++) {
      final rowCells = List<TerminalPaintCell>.generate(frame.cols, (col) {
        final index = row * frame.cols + col;
        if (index >= frame.cells.length) {
          return const TerminalPaintCell(
            codepoint: 0,
            width: 0,
            fgArgb: 0xFFFFFFFF,
            bgArgb: 0xFF000000,
          );
        }
        final cell = frame.cells[index];
        final fg = _toColor(cell.fg, fallback: const Color(0xFFDDDDDD));
        final bg = _toColor(cell.bg, fallback: const Color(0xFF000000));
        return TerminalPaintCell(
          codepoint: cell.codepoint,
          width: cell.width,
          fgArgb: fg.toARGB32(),
          bgArgb: bg.toARGB32(),
        );
      });
      final plan = TerminalPaintRuns.planRow(cells: rowCells, cols: frame.cols);

      for (final bgRun in plan.backgroundRuns) {
        final fillRect = _snappedRunFillRect(
          layout: layout,
          row: row,
          startCol: bgRun.startCol,
          endColExclusive: bgRun.endColExclusive,
        );
        cellPaint.color = Color(bgRun.bgArgb);
        canvas.drawRect(fillRect, cellPaint);
      }

      // Keep terminal cursor/text ownership strictly cell-based.
      for (var col = 0; col < frame.cols; col++) {
        final index = row * frame.cols + col;
        if (index >= frame.cells.length) {
          continue;
        }
        final cell = frame.cells[index];
        if (cell.width != 1 || cell.codepoint < 32 || cell.codepoint == 127) {
          continue;
        }
        final rect = layout.cellRect(row: row, col: col);
        final fg = _toColor(cell.fg, fallback: const Color(0xFFDDDDDD));
        final glyphFlags = glyphClassLookup(cell.codepoint);
        if (_paintRoundedBoxCornerGlyph(
          canvas: canvas,
          rect: rect,
          codepoint: cell.codepoint,
          color: fg,
          cellWidth: cellWidth,
          cellHeight: cellHeight,
        )) {
          continue;
        }
        if (_paintBoxLinesGlyph(
          canvas: canvas,
          rect: rect,
          codepoint: cell.codepoint,
          glyphClassFlags: glyphFlags,
          color: fg,
          cellWidth: cellWidth,
          cellHeight: cellHeight,
        )) {
          continue;
        }
        final cacheKey = Object.hash(
          cell.codepoint,
          fg.toARGB32(),
          1,
          glyphStyle.fontSize,
        );
        var painter = glyphCache[cacheKey];
        if (painter == null) {
          painter = TextPainter(
            text: TextSpan(
              text: String.fromCharCode(cell.codepoint),
              style: glyphStyle.copyWith(color: fg),
            ),
            textDirection: TextDirection.ltr,
            maxLines: 1,
          )..layout(minWidth: 0, maxWidth: cellWidth);
          glyphCache[cacheKey] = painter;
        }
        final useCellOrigin = _shouldUseCellOrigin(
          codepoint: cell.codepoint,
          glyphClassFlags: glyphFlags,
        );
        final glyphLeft = useCellOrigin
            ? rect.left
            : rect.left + math.max(0.0, (cellWidth - painter.width) / 2);
        final glyphTop = useCellOrigin
            ? rect.top
            : rect.top + (cellHeight - painter.height) / 2;
        painter.paint(canvas, Offset(glyphLeft, glyphTop));
      }

      for (final glyph in plan.fallbackGlyphs) {
        final rect = layout.cellRect(row: row, col: glyph.col);
        final spanCells = glyph.width <= 1 ? 1 : 2;
        final maxGlyphWidth = cellWidth * spanCells;
        final glyphFlags = glyphClassLookup(glyph.codepoint);
        if (_paintRoundedBoxCornerGlyph(
          canvas: canvas,
          rect: Rect.fromLTWH(rect.left, rect.top, maxGlyphWidth, cellHeight),
          codepoint: glyph.codepoint,
          color: Color(glyph.fgArgb),
          cellWidth: maxGlyphWidth,
          cellHeight: cellHeight,
        )) {
          continue;
        }
        if (_paintBoxLinesGlyph(
          canvas: canvas,
          rect: Rect.fromLTWH(rect.left, rect.top, maxGlyphWidth, cellHeight),
          codepoint: glyph.codepoint,
          glyphClassFlags: glyphFlags,
          color: Color(glyph.fgArgb),
          cellWidth: maxGlyphWidth,
          cellHeight: cellHeight,
        )) {
          continue;
        }
        final cacheKey = Object.hash(
          glyph.codepoint,
          glyph.fgArgb,
          spanCells,
          glyphStyle.fontSize,
        );
        var painter = glyphCache[cacheKey];
        if (painter == null) {
          painter = TextPainter(
            text: TextSpan(
              text: String.fromCharCode(glyph.codepoint),
              style: glyphStyle.copyWith(color: Color(glyph.fgArgb)),
            ),
            textDirection: TextDirection.ltr,
            maxLines: 1,
          )..layout(minWidth: 0, maxWidth: maxGlyphWidth);
          glyphCache[cacheKey] = painter;
        }
        final useCellOrigin = _shouldUseCellOrigin(
          codepoint: glyph.codepoint,
          glyphClassFlags: glyphFlags,
        );
        final glyphLeft = useCellOrigin
            ? rect.left
            : rect.left + math.max(0.0, (maxGlyphWidth - painter.width) / 2);
        final glyphTop = useCellOrigin
            ? rect.top
            : rect.top + (cellHeight - painter.height) / 2;
        painter.paint(canvas, Offset(glyphLeft, glyphTop));
      }
    }
    canvas.restore();

    if (frame.cursorVisible &&
        frame.cursorRow >= 0 &&
        frame.cursorRow < frame.rows &&
        frame.cursorCol >= 0 &&
        frame.cursorCol < frame.cols) {
      final cursorRect = layout.cellRect(
        row: frame.cursorRow,
        col: frame.cursorCol,
      );
      final cursorPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, 1.5 * layout.scale.clamp(0.8, 1.6))
        ..color = const Color(0xFFFFFFFF);
      canvas.drawRect(cursorRect.deflate(1), cursorPaint);
    }
  }

  Color _toColor(ZideTerminalColorData source, {required Color fallback}) {
    if (source.a == 0) {
      return fallback;
    }
    return Color.fromARGB(source.a, source.r, source.g, source.b);
  }

  @override
  bool shouldRepaint(covariant _ZideTerminalPainter oldDelegate) {
    return oldDelegate.frame != frame;
  }

  Rect _snappedRunFillRect({
    required TerminalPaintLayout layout,
    required int row,
    required int startCol,
    required int endColExclusive,
  }) {
    final left = layout.originX + startCol * layout.cellWidth;
    final top = layout.originY + row * layout.cellHeight;
    final right = layout.originX + endColExclusive * layout.cellWidth;
    final bottom = top + layout.cellHeight;
    return Rect.fromLTRB(
      left.floorToDouble(),
      top.floorToDouble(),
      right.ceilToDouble(),
      bottom.ceilToDouble(),
    );
  }

  bool _isGridCodepoint(int codepoint) {
    return codepoint >= _boxDrawStart && codepoint <= _gridCharEnd;
  }

  bool _paintRoundedBoxCornerGlyph({
    required Canvas canvas,
    required Rect rect,
    required int codepoint,
    required Color color,
    required double cellWidth,
    required double cellHeight,
  }) {
    if (codepoint != 0x256D &&
        codepoint != 0x256E &&
        codepoint != 0x256F &&
        codepoint != 0x2570) {
      return false;
    }
    final stroke = math.max(2.1, math.min(cellWidth, cellHeight) * 0.19);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.square
      ..isAntiAlias = true;

    Rect ovalAt(double cx, double cy) => Rect.fromCenter(
      center: Offset(cx, cy),
      width: cellWidth,
      height: cellHeight,
    );

    switch (codepoint) {
      case 0x256D: // ╭ : right + down
        canvas.drawArc(
          ovalAt(rect.right, rect.bottom),
          math.pi,
          math.pi / 2,
          false,
          paint,
        );
      case 0x256E: // ╮ : left + down
        canvas.drawArc(
          ovalAt(rect.left, rect.bottom),
          3 * math.pi / 2,
          math.pi / 2,
          false,
          paint,
        );
      case 0x256F: // ╯ : left + up
        canvas.drawArc(
          ovalAt(rect.left, rect.top),
          0,
          math.pi / 2,
          false,
          paint,
        );
      case 0x2570: // ╰ : right + up
        canvas.drawArc(
          ovalAt(rect.right, rect.top),
          math.pi / 2,
          math.pi / 2,
          false,
          paint,
        );
      default:
        return false;
    }
    return true;
  }

  bool _paintBoxLinesGlyph({
    required Canvas canvas,
    required Rect rect,
    required int codepoint,
    required int glyphClassFlags,
    required Color color,
    required double cellWidth,
    required double cellHeight,
  }) {
    if (!_shouldUseCustomBoxLines(
      codepoint: codepoint,
      glyphClassFlags: glyphClassFlags,
    )) {
      return false;
    }
    final spec = _boxSpecFor(codepoint);
    if (spec == null) {
      return false;
    }

    final base = math.max(1.0, math.min(cellWidth, cellHeight) * 0.09);
    final light = base;
    final heavy = math.max(light + 0.75, light * 1.7);
    final centerX = (rect.left + rect.right) / 2;
    final centerY = (rect.top + rect.bottom) / 2;
    final paint = Paint()
      ..color = color
      ..isAntiAlias = false
      ..style = PaintingStyle.fill;

    void fillRect(double left, double top, double right, double bottom) {
      canvas.drawRect(
        Rect.fromLTRB(
          left.floorToDouble(),
          top.floorToDouble(),
          right.ceilToDouble(),
          bottom.ceilToDouble(),
        ),
        paint,
      );
    }

    if (spec.up) {
      final t = spec.heavyUp ? heavy : light;
      fillRect(centerX - t / 2, rect.top, centerX + t / 2, centerY);
    }
    if (spec.down) {
      final t = spec.heavyDown ? heavy : light;
      fillRect(centerX - t / 2, centerY, centerX + t / 2, rect.bottom);
    }
    if (spec.left) {
      final t = spec.heavyLeft ? heavy : light;
      fillRect(rect.left, centerY - t / 2, centerX, centerY + t / 2);
    }
    if (spec.right) {
      final t = spec.heavyRight ? heavy : light;
      fillRect(centerX, centerY - t / 2, rect.right, centerY + t / 2);
    }
    return true;
  }

  bool _shouldUseCustomBoxLines({
    required int codepoint,
    required int glyphClassFlags,
  }) {
    if (glyphClassFlags != 0) {
      final isBox =
          (glyphClassFlags & ZideTerminalFfiBridge.glyphClassBox) != 0;
      final isRounded =
          (glyphClassFlags & ZideTerminalFfiBridge.glyphClassBoxRounded) != 0;
      return isBox && !isRounded && codepoint <= _boxDrawHardEnd;
    }
    return codepoint >= _boxDrawStart && codepoint <= _boxDrawHardEnd;
  }

  bool _shouldUseCellOrigin({
    required int codepoint,
    required int glyphClassFlags,
  }) {
    if (glyphClassFlags != 0) {
      return (glyphClassFlags &
              (ZideTerminalFfiBridge.glyphClassBoxRounded |
                  ZideTerminalFfiBridge.glyphClassGraph |
                  ZideTerminalFfiBridge.glyphClassBraille |
                  ZideTerminalFfiBridge.glyphClassPowerline |
                  ZideTerminalFfiBridge.glyphClassPowerlineRounded)) !=
          0;
    }
    return _isGridCodepoint(codepoint);
  }

  _BoxSpec? _boxSpecFor(int codepoint) {
    return switch (codepoint) {
      0x2500 => const _BoxSpec(left: true, right: true),
      0x2501 => const _BoxSpec(
        left: true,
        right: true,
        heavyLeft: true,
        heavyRight: true,
      ),
      0x2502 => const _BoxSpec(up: true, down: true),
      0x2503 => const _BoxSpec(
        up: true,
        down: true,
        heavyUp: true,
        heavyDown: true,
      ),
      0x250C => const _BoxSpec(right: true, down: true),
      0x250F => const _BoxSpec(
        right: true,
        down: true,
        heavyRight: true,
        heavyDown: true,
      ),
      0x2510 => const _BoxSpec(left: true, down: true),
      0x2513 => const _BoxSpec(
        left: true,
        down: true,
        heavyLeft: true,
        heavyDown: true,
      ),
      0x2514 => const _BoxSpec(up: true, right: true),
      0x2517 => const _BoxSpec(
        up: true,
        right: true,
        heavyUp: true,
        heavyRight: true,
      ),
      0x2518 => const _BoxSpec(up: true, left: true),
      0x251B => const _BoxSpec(
        up: true,
        left: true,
        heavyUp: true,
        heavyLeft: true,
      ),
      0x251C => const _BoxSpec(up: true, down: true, right: true),
      0x2523 => const _BoxSpec(
        up: true,
        down: true,
        right: true,
        heavyUp: true,
        heavyDown: true,
        heavyRight: true,
      ),
      0x2524 => const _BoxSpec(up: true, down: true, left: true),
      0x252B => const _BoxSpec(
        up: true,
        down: true,
        left: true,
        heavyUp: true,
        heavyDown: true,
        heavyLeft: true,
      ),
      0x252C => const _BoxSpec(left: true, right: true, down: true),
      0x2533 => const _BoxSpec(
        left: true,
        right: true,
        down: true,
        heavyLeft: true,
        heavyRight: true,
        heavyDown: true,
      ),
      0x2534 => const _BoxSpec(left: true, right: true, up: true),
      0x253B => const _BoxSpec(
        left: true,
        right: true,
        up: true,
        heavyLeft: true,
        heavyRight: true,
        heavyUp: true,
      ),
      0x253C => const _BoxSpec(up: true, down: true, left: true, right: true),
      0x254B => const _BoxSpec(
        up: true,
        down: true,
        left: true,
        right: true,
        heavyUp: true,
        heavyDown: true,
        heavyLeft: true,
        heavyRight: true,
      ),
      _ => null,
    };
  }
}

class _BoxSpec {
  const _BoxSpec({
    this.up = false,
    this.down = false,
    this.left = false,
    this.right = false,
    this.heavyUp = false,
    this.heavyDown = false,
    this.heavyLeft = false,
    this.heavyRight = false,
  });

  final bool up;
  final bool down;
  final bool left;
  final bool right;
  final bool heavyUp;
  final bool heavyDown;
  final bool heavyLeft;
  final bool heavyRight;
}
