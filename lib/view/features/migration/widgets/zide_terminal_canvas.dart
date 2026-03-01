import 'dart:async';
import 'dart:convert';
import 'dart:ffi' show Pointer;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

import 'package:cwatch/model/services_infra/settings/app_settings_controller.dart';
import 'package:cwatch/model/services_infra/zide/zide_terminal_ffi_bridge.dart';
import 'support/terminal_scrollback_controller.dart';

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
  ZideTerminalFfiBridge? _bridge;
  Pointer<ZideTerminalHandle>? _handle;
  Timer? _timer;
  final FocusNode _focusNode = FocusNode(debugLabel: 'zide_terminal_canvas');
  late final TextEditingController _commandController;

  String _status = 'Initializing terminal...';
  String _inputMatrixStatus = 'input matrix: not run';
  String _commandRunStatus = 'command runner: idle';
  bool _shellStarted = false;
  bool _commandRunning = false;
  final TerminalScrollbackController _scrollback =
      TerminalScrollbackController();

  @override
  void initState() {
    super.initState();
    _commandController = TextEditingController(
      text: "printf '[{ts}] hello-from-pty\\n'",
    );
    _initTerminal();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _focusNode.dispose();
    _commandController.dispose();
    final handle = _handle;
    final bridge = _bridge;
    if (handle != null && bridge != null) {
      bridge.destroy(handle);
    }
    super.dispose();
  }

  void _initTerminal() {
    try {
      final bridge = ZideTerminalFfiBridge.open(
        settings: widget.settingsController.settings,
      );
      final handle = bridge.create(
        rows: 18,
        cols: 72,
        scrollbackRows: 512,
        cursorShape: 0,
        cursorBlink: true,
      );
      bridge.resize(handle, cols: 72, rows: 18, cellWidth: 8, cellHeight: 16);
      bridge.feedOutput(handle, utf8.encode('\x1b]0;zide-migration\x07'));

      _bridge = bridge;
      _handle = handle;
      _status = 'Connected: ${bridge.libraryPath}';
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
    final bridge = _bridge;
    final handle = _handle;
    if (bridge == null || handle == null) {
      return;
    }

    try {
      bridge.poll(handle);
      final snapshot = bridge.acquireSnapshot(handle);
      try {
        final meta = bridge.readSnapshot(snapshot);
        final frame = bridge.snapshotToFrame(snapshot);
        _scrollback.updateLiveFrame(frame: frame);
        if (!mounted) {
          return;
        }
        setState(() {
          final mode = _scrollback.modeLabel();
          _status =
              'rows=${meta.rows} total_rows=${frame.rows} cols=${meta.cols} '
              'title=${meta.title.isEmpty ? '(none)' : meta.title} mode=$mode';
        });
      } finally {
        bridge.releaseSnapshot(snapshot);
      }
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
    setState(() {
      _scrollback.scrollUp(rows: rows);
    });
  }

  void _historyDown({int rows = 1}) {
    setState(() {
      _scrollback.scrollDown(rows: rows);
    });
  }

  void _historyLive() {
    setState(() {
      _scrollback.scrollLive();
    });
  }

  Future<void> _copyVisible() async {
    final frame = _effectiveFrame;
    final text = _frameToPlainText(frame);
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) {
      return;
    }
    setState(() {
      _inputMatrixStatus = 'copy visible: ${text.length} chars copied';
    });
  }

  Future<void> _pasteClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text ?? '';
    if (text.isEmpty) {
      if (!mounted) {
        return;
      }
      setState(() {
        _inputMatrixStatus = 'paste clipboard: empty';
      });
      return;
    }
    _sendBytes(utf8.encode(text));
    if (!mounted) {
      return;
    }
    setState(() {
      _inputMatrixStatus = 'paste clipboard: sent ${text.length} chars';
    });
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
    final bridge = _bridge;
    final handle = _handle;
    if (bridge == null || handle == null || bytes.isEmpty) {
      return;
    }
    try {
      _ensureShellStarted();
      bridge.sendBytes(handle, bytes);
    } catch (_) {
      // For feed-only sessions sendBytes may be ignored by backend, which is
      // acceptable in this prototype widget.
    }
  }

  void _ensureShellStarted() {
    if (_shellStarted) {
      return;
    }
    final bridge = _bridge;
    final handle = _handle;
    if (bridge == null || handle == null) {
      return;
    }
    bridge.start(handle, shell: '/bin/sh');
    _shellStarted = true;
    _commandRunStatus = 'command runner: shell started (interactive)';
  }

  void _feedFixture(String vt) {
    final bridge = _bridge;
    final handle = _handle;
    if (bridge == null || handle == null) {
      return;
    }
    bridge.feedOutput(handle, utf8.encode(vt));
    _refresh();
  }

  void _runInputMatrixProbe() {
    final bridge = _bridge;
    final handle = _handle;
    if (bridge == null || handle == null) {
      return;
    }

    try {
      final beforeSnapshot = bridge.acquireSnapshot(handle);
      late final ZideTerminalSnapshotData before;
      try {
        before = bridge.readSnapshot(beforeSnapshot);
      } finally {
        bridge.releaseSnapshot(beforeSnapshot);
      }

      bridge.feedOutput(handle, utf8.encode('\x1b[2A\x1b[5C'));
      bridge.poll(handle);

      final afterSnapshot = bridge.acquireSnapshot(handle);
      try {
        final after = bridge.readSnapshot(afterSnapshot);
        final expectedRow = (before.cursorRow - 2)
            .clamp(0, before.rows - 1)
            .toInt();
        final expectedCol = (before.cursorCol + 5)
            .clamp(0, before.cols - 1)
            .toInt();
        final pass =
            after.cursorRow == expectedRow && after.cursorCol == expectedCol;
        setState(() {
          _inputMatrixStatus =
              'input matrix probe ${pass ? 'PASS' : 'FAIL'} '
              'expected=$expectedRow,$expectedCol actual=${after.cursorRow},${after.cursorCol}';
        });
      } finally {
        bridge.releaseSnapshot(afterSnapshot);
      }
    } catch (error) {
      setState(() {
        _inputMatrixStatus = 'input matrix probe error: $error';
      });
    }
  }

  String _inputMatrixLegend() {
    const matrix = <String, List<int>>{
      'enter': [13],
      'tab': [9],
      'backspace': [127],
      'arrow_up': [27, 91, 65],
      'arrow_down': [27, 91, 66],
      'arrow_right': [27, 91, 67],
      'arrow_left': [27, 91, 68],
      'ctrl+a': [1],
      'ctrl+z': [26],
    };
    return matrix.entries
        .map((entry) => '${entry.key}=${entry.value.join(",")}')
        .join('  ');
  }

  Future<void> _runShellCommand() async {
    final bridge = _bridge;
    final handle = _handle;
    if (bridge == null || handle == null || _commandRunning) {
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
        bridge.poll(handle);
        await Future<void>.delayed(const Duration(milliseconds: 15));
      }

      bridge.sendBytes(handle, utf8.encode(payload));

      var sawMarker = false;
      for (var i = 0; i < 80; i++) {
        bridge.poll(handle);
        final snapshot = bridge.acquireSnapshot(handle);
        try {
          final text = bridge.snapshotToPlainText(snapshot);
          if (text.contains(marker)) {
            sawMarker = true;
            break;
          }
        } finally {
          bridge.releaseSnapshot(snapshot);
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

  void _onKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) {
      return;
    }
    _ensureShellStarted();

    final logical = event.logicalKey;
    if (logical == LogicalKeyboardKey.enter) {
      _sendBytes(const [13]);
      return;
    }
    if (logical == LogicalKeyboardKey.backspace) {
      _sendBytes(const [127]);
      return;
    }
    if (logical == LogicalKeyboardKey.tab) {
      _sendBytes(const [9]);
      return;
    }
    if (logical == LogicalKeyboardKey.arrowUp) {
      _sendBytes(const [27, 91, 65]);
      return;
    }
    if (logical == LogicalKeyboardKey.arrowDown) {
      _sendBytes(const [27, 91, 66]);
      return;
    }
    if (logical == LogicalKeyboardKey.arrowRight) {
      _sendBytes(const [27, 91, 67]);
      return;
    }
    if (logical == LogicalKeyboardKey.arrowLeft) {
      _sendBytes(const [27, 91, 68]);
      return;
    }

    final character = event.character;
    if (character == null || character.isEmpty) {
      return;
    }

    if (HardwareKeyboard.instance.isControlPressed && character.length == 1) {
      final codeUnit = character.toUpperCase().codeUnitAt(0);
      if (codeUnit >= 65 && codeUnit <= 90) {
        _sendBytes([codeUnit - 64]);
        return;
      }
    }

    _sendBytes(utf8.encode(character));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF111111),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
              border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _status,
                  style: const TextStyle(
                    fontFamily: 'JetBrainsMono Nerd Font Mono',
                    color: Color(0xFFDDDDDD),
                    fontSize: 12,
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
                      onPressed: () => _feedFixture('fixture: hello world\r\n'),
                      child: const Text('Fixture hello'),
                    ),
                    OutlinedButton(
                      onPressed: () => _feedFixture(
                        '\x1b[31mRED\x1b[0m \x1b[32mGREEN\x1b[0m '
                        '\x1b[34mBLUE\x1b[0m\r\n',
                      ),
                      child: const Text('Fixture colors'),
                    ),
                    OutlinedButton(
                      onPressed: () => _feedFixture(
                        'cursor demo: start\r\n'
                        '\x1b[2A'
                        '\x1b[15C'
                        'X',
                      ),
                      child: const Text('Fixture cursor'),
                    ),
                    OutlinedButton(
                      onPressed: _runInputMatrixProbe,
                      child: const Text('Input matrix probe'),
                    ),
                    OutlinedButton(
                      onPressed: _copyVisible,
                      child: const Text('Copy visible'),
                    ),
                    OutlinedButton(
                      onPressed: _pasteClipboard,
                      child: const Text('Paste clipboard'),
                    ),
                    OutlinedButton(
                      onPressed: _historyUp,
                      child: const Text('Scrollback up'),
                    ),
                    OutlinedButton(
                      onPressed: _historyDown,
                      child: const Text('Scrollback down'),
                    ),
                    OutlinedButton(
                      onPressed: _historyLive,
                      child: const Text('Scrollback live'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _inputMatrixStatus,
                  style: const TextStyle(
                    fontFamily: 'JetBrainsMono Nerd Font Mono',
                    color: Color(0xFFC9C9C9),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _inputMatrixLegend(),
                  style: const TextStyle(
                    fontFamily: 'JetBrainsMono Nerd Font Mono',
                    color: Color(0xFF999999),
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commandController,
                        style: const TextStyle(
                          fontFamily: 'JetBrainsMono Nerd Font Mono',
                          fontSize: 12,
                          color: Color(0xFFDDDDDD),
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
                      onPressed: _commandRunning ? null : _runShellCommand,
                      child: const Text('Run command'),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _commandRunStatus,
                  style: const TextStyle(
                    fontFamily: 'JetBrainsMono Nerd Font Mono',
                    color: Color(0xFFC9C9C9),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: KeyboardListener(
              focusNode: _focusNode,
              onKeyEvent: _onKeyEvent,
              child: Listener(
                onPointerSignal: (signal) {
                  if (signal is PointerScrollEvent) {
                    if (signal.scrollDelta.dy > 0) {
                      _historyUp(rows: 3);
                    } else if (signal.scrollDelta.dy < 0) {
                      _historyDown(rows: 3);
                    }
                  }
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    _focusNode.requestFocus();
                    _ensureShellStarted();
                    _refresh();
                  },
                  child: MouseRegion(
                    onEnter: (_) => widget.onPointerHoverChanged?.call(true),
                    onExit: (_) => widget.onPointerHoverChanged?.call(false),
                    child: CustomPaint(
                      painter: _ZideTerminalPainter(frame: _effectiveFrame),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ZideTerminalPainter extends CustomPainter {
  _ZideTerminalPainter({required this.frame});

  final ZideTerminalFrameData frame;
  static const double _modelCellWidth = 8;
  static const double _modelCellHeight = 16;

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFF000000);
    canvas.drawRect(Offset.zero & size, bgPaint);

    if (frame.rows <= 0 || frame.cols <= 0 || frame.cells.isEmpty) {
      return;
    }

    final fitScale = (size.width / (frame.cols * _modelCellWidth)).clamp(
      0.01,
      double.infinity,
    );
    final fitScaleY = (size.height / (frame.rows * _modelCellHeight)).clamp(
      0.01,
      double.infinity,
    );
    final scale = fitScale < fitScaleY ? fitScale : fitScaleY;

    final cellWidth = _modelCellWidth * scale;
    final cellHeight = _modelCellHeight * scale;
    final gridWidth = frame.cols * cellWidth;
    final gridHeight = frame.rows * cellHeight;
    final originX = (size.width - gridWidth) / 2;
    final originY = (size.height - gridHeight) / 2;

    final cellPaint = Paint();
    final glyphStyle = TextStyle(
      fontFamily: 'JetBrainsMono Nerd Font Mono',
      fontSize: cellHeight * 0.78,
      height: 1.0,
    );
    for (var row = 0; row < frame.rows; row++) {
      for (var col = 0; col < frame.cols; col++) {
        final index = row * frame.cols + col;
        if (index >= frame.cells.length) {
          continue;
        }
        final cell = frame.cells[index];
        final rect = Rect.fromLTWH(
          originX + col * cellWidth,
          originY + row * cellHeight,
          cellWidth,
          cellHeight,
        );

        final bg = _toColor(cell.bg, fallback: const Color(0xFF000000));
        cellPaint.color = bg;
        canvas.drawRect(rect, cellPaint);

        if (cell.width == 0 || cell.codepoint == 0) {
          continue;
        }

        final fg = _toColor(cell.fg, fallback: const Color(0xFFDDDDDD));
        final charCode = cell.codepoint;
        if (charCode < 32 || charCode == 127) {
          continue;
        }
        final painter = TextPainter(
          text: TextSpan(
            text: String.fromCharCode(charCode),
            style: glyphStyle.copyWith(color: fg),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout(minWidth: 0, maxWidth: cellWidth * (cell.width <= 1 ? 1 : 2));

        painter.paint(
          canvas,
          Offset(rect.left + 1, rect.top + (cellHeight - painter.height) / 2),
        );
      }
    }

    if (frame.cursorVisible &&
        frame.cursorRow >= 0 &&
        frame.cursorRow < frame.rows &&
        frame.cursorCol >= 0 &&
        frame.cursorCol < frame.cols) {
      final cursorRect = Rect.fromLTWH(
        originX + frame.cursorCol * cellWidth,
        originY + frame.cursorRow * cellHeight,
        cellWidth,
        cellHeight,
      );
      final cursorPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
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
}
