import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

import 'package:cwatch/model/services_infra/logging/app_logger.dart';
import 'package:cwatch/model/services_infra/settings/app_settings_controller.dart';
import 'package:cwatch/model/services_infra/zide/zide_terminal_ffi_bridge.dart';
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
  ZideTerminalSessionController? _session;
  Timer? _timer;
  final FocusNode _focusNode = FocusNode(debugLabel: 'zide_terminal_canvas');
  late final TextEditingController _commandController;

  String _status = 'Initializing terminal...';
  String _commandRunStatus = 'command runner: idle';
  bool _commandRunning = false;
  bool _followLiveOnInput = true;
  final TerminalScrollbackController _scrollback =
      TerminalScrollbackController();

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
        final mode = _scrollback.modeLabel();
        final scrollbackBackend = poll.usingNativeScrollback
            ? 'native'
            : 'fallback';
        _status =
            'rows=${meta.rows} total_rows=${frame.rows} cols=${meta.cols} '
            'title=${meta.title.isEmpty ? '(none)' : meta.title} '
            'scrollback=$scrollbackBackend mode=$mode';
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
                        style: const TextStyle(
                          fontFamily: 'JetBrainsMono Nerd Font Mono',
                          color: Color(0xFFDDDDDD),
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    : Column(
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
                        final dy = signal.scrollDelta.dy;
                        final steps = (dy.abs() / 24.0).ceil().clamp(1, 8);
                        final rows = steps * 3;
                        AppLogger().debug(
                          'wheel dy=${dy.toStringAsFixed(2)} steps=$steps rows=$rows focus=${_focusNode.hasFocus} mode=${_scrollback.modeLabel()}',
                          tag: _logTag,
                        );
                        if (dy < 0) {
                          _historyUp(rows: rows);
                        } else if (dy > 0) {
                          _historyDown(rows: rows);
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
                        onEnter: (_) =>
                            widget.onPointerHoverChanged?.call(true),
                        onExit: (_) =>
                            widget.onPointerHoverChanged?.call(false),
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
      },
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
