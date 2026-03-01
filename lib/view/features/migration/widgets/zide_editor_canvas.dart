import 'dart:ffi' show Pointer;
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:cwatch/model/services_infra/settings/app_settings_controller.dart';
import 'package:cwatch/model/services_infra/zide/zide_editor_ffi_bridge.dart';
import 'support/editor_caret_layout.dart';

class ZideEditorCanvas extends StatefulWidget {
  const ZideEditorCanvas({super.key, required this.settingsController});

  final AppSettingsController settingsController;

  @override
  State<ZideEditorCanvas> createState() => _ZideEditorCanvasState();
}

class _ZideEditorCanvasState extends State<ZideEditorCanvas> {
  ZideEditorFfiBridge? _bridge;
  Pointer<ZideEditorHandle>? _handle;
  final FocusNode _focusNode = FocusNode(debugLabel: 'zide_editor_canvas');
  final ScrollController _verticalScrollController = ScrollController();

  String _status = 'Initializing editor...';
  String _text = '';
  int _lineCount = 0;
  int _primaryCaret = 0;
  int _auxCount = 0;
  List<int> _auxOffsets = const [];
  int _matchCount = 0;
  String _activeMatch = 'none';
  String _keyStatus = 'keyboard: idle';
  int? _selectionAnchor;
  int? _selectionFocus;

  @override
  void initState() {
    super.initState();
    _initEditor();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _verticalScrollController.dispose();
    final bridge = _bridge;
    final handle = _handle;
    if (bridge != null && handle != null) {
      bridge.destroy(handle);
    }
    super.dispose();
  }

  void _initEditor() {
    try {
      final bridge = ZideEditorFfiBridge.open(
        settings: widget.settingsController.settings,
      );
      final handle = bridge.create();
      final initialText = _loadMainZigText();
      bridge.setText(handle, initialText);
      _bridge = bridge;
      _handle = handle;
      _status = 'Connected: ${bridge.libraryPath}';
      _refresh();
      setState(() {});
    } catch (error) {
      setState(() {
        _status = 'Editor unavailable: $error';
      });
    }
  }

  String _loadMainZigText() {
    final home = Platform.environment['HOME']?.trim();
    if (home == null || home.isEmpty) {
      return 'migration canvas\nline two\n';
    }
    final file = File('$home/personal/zide/src/main.zig');
    if (!file.existsSync()) {
      return 'migration canvas\nline two\n';
    }
    try {
      final content = file.readAsStringSync();
      if (content.trim().isEmpty) {
        return 'migration canvas\nline two\n';
      }
      return content;
    } catch (_) {
      return 'migration canvas\nline two\n';
    }
  }

  void _reloadMainZig() {
    final bridge = _bridge;
    final handle = _handle;
    if (bridge == null || handle == null) {
      return;
    }
    final text = _loadMainZigText();
    bridge.setText(handle, text);
    bridge.setCursorOffset(handle, 0);
    _clearSelection();
    _keyStatus = 'keyboard: reloaded main.zig';
    _refresh();
  }

  void _refresh() {
    final bridge = _bridge;
    final handle = _handle;
    if (bridge == null || handle == null) {
      return;
    }
    try {
      final primary = bridge.primaryCaretOffset(handle);
      final auxCount = bridge.auxCaretCount(handle);
      final lineCount = bridge.lineCount(handle);
      final matchCount = bridge.searchMatchCount(handle);
      final active = bridge.searchActiveIndex(handle);
      final text = bridge.textAlloc(handle);
      if (!mounted) {
        return;
      }
      setState(() {
        final auxOffsets = <int>[];
        for (var i = 0; i < auxCount; i++) {
          auxOffsets.add(bridge.auxCaretGet(handle, i));
        }
        _text = text;
        _lineCount = lineCount;
        _primaryCaret = primary;
        _auxCount = auxCount;
        _auxOffsets = auxOffsets;
        _matchCount = matchCount;
        _activeMatch = active.hasActive ? '${active.index}' : 'none';
        _status =
            'lines=$lineCount primary_caret=$primary aux=$auxCount matches=$matchCount active=$_activeMatch';
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

  void _undo() {
    final bridge = _bridge;
    final handle = _handle;
    if (bridge == null || handle == null) {
      return;
    }
    bridge.undo(handle);
    _refresh();
  }

  void _redo() {
    final bridge = _bridge;
    final handle = _handle;
    if (bridge == null || handle == null) {
      return;
    }
    bridge.redo(handle);
    _refresh();
  }

  void _focusKeyboard() {
    _focusNode.requestFocus();
    setState(() {
      _keyStatus = 'keyboard: focused';
    });
  }

  ({int start, int end})? _selectionRange() {
    final anchor = _selectionAnchor;
    final focus = _selectionFocus;
    if (anchor == null || focus == null || anchor == focus) {
      return null;
    }
    return (start: math.min(anchor, focus), end: math.max(anchor, focus));
  }

  void _clearSelection() {
    _selectionAnchor = null;
    _selectionFocus = null;
  }

  void _setCaretFromTap(Offset localPosition, double contentWidth) {
    final bridge = _bridge;
    final handle = _handle;
    if (bridge == null || handle == null) {
      return;
    }
    try {
      // The editable surface uses 8px content padding around text paint.
      final textPoint = Offset(localPosition.dx - 8, localPosition.dy - 8);
      final offset = EditorCaretLayout.offsetFromPoint(
        text: _text,
        point: textPoint,
        textScaler: MediaQuery.textScalerOf(context),
        maxWidth: contentWidth,
        style: _EditorTextWithCaretPainter.textStyle,
      );
      bridge.setCursorOffset(handle, offset);
      _clearSelection();
      _keyStatus = 'keyboard: click caret=$offset';
      _refresh();
    } catch (error) {
      setState(() {
        _keyStatus = 'keyboard click error: $error';
      });
    }
  }

  void _updateSelectionFromDrag({
    required Offset localPosition,
    required double contentWidth,
    required bool start,
  }) {
    final bridge = _bridge;
    final handle = _handle;
    if (bridge == null || handle == null) {
      return;
    }
    final textPoint = Offset(localPosition.dx - 8, localPosition.dy - 8);
    final offset = EditorCaretLayout.offsetFromPoint(
      text: _text,
      point: textPoint,
      textScaler: MediaQuery.textScalerOf(context),
      maxWidth: contentWidth,
      style: _EditorTextWithCaretPainter.textStyle,
    );
    if (start || _selectionAnchor == null) {
      _selectionAnchor = offset;
      _selectionFocus = offset;
    } else {
      _selectionFocus = offset;
    }
    bridge.setCursorOffset(handle, _selectionFocus ?? offset);
    _keyStatus = 'keyboard: drag selection';
    _refresh();
  }

  void _onEditorKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) {
      return;
    }
    final bridge = _bridge;
    final handle = _handle;
    if (bridge == null || handle == null) {
      return;
    }

    try {
      final logical = event.logicalKey;
      final ctrl = HardwareKeyboard.instance.isControlPressed;
      final shift = HardwareKeyboard.instance.isShiftPressed;

      if (_handleViewportShortcut(logical: logical, ctrl: ctrl)) {
        return;
      }

      if (ctrl && logical == LogicalKeyboardKey.keyZ) {
        bridge.undo(handle);
        _keyStatus = 'keyboard: ctrl+z';
        _refresh();
        return;
      }
      if (ctrl &&
          (logical == LogicalKeyboardKey.keyY ||
              (HardwareKeyboard.instance.isShiftPressed &&
                  logical == LogicalKeyboardKey.keyZ))) {
        bridge.redo(handle);
        _keyStatus = 'keyboard: redo';
        _refresh();
        return;
      }
      if (ctrl && logical == LogicalKeyboardKey.keyA) {
        final totalLen = bridge.totalLength(handle);
        _selectionAnchor = 0;
        _selectionFocus = totalLen;
        bridge.setCursorOffset(handle, totalLen);
        _keyStatus = 'keyboard: ctrl+a';
        _refresh();
        return;
      }

      var cursor = bridge.cursorOffset(handle);
      final totalLen = bridge.totalLength(handle);
      final selection = _selectionRange();

      void moveCursor({
        required int next,
        required String baseLabel,
        required bool shiftSelect,
      }) {
        final clamped = next.clamp(0, totalLen);
        if (shiftSelect) {
          _selectionAnchor ??= cursor;
          _selectionFocus = clamped;
          bridge.setCursorOffset(handle, clamped);
          _keyStatus = 'keyboard: shift+$baseLabel';
        } else {
          _clearSelection();
          bridge.setCursorOffset(handle, clamped);
          _keyStatus = 'keyboard: $baseLabel';
        }
        _refresh();
      }

      if (logical == LogicalKeyboardKey.arrowLeft) {
        final next = cursor > 0 ? cursor - 1 : 0;
        moveCursor(next: next, baseLabel: 'left', shiftSelect: shift);
        return;
      }
      if (logical == LogicalKeyboardKey.arrowRight) {
        final next = cursor < totalLen ? cursor + 1 : totalLen;
        moveCursor(next: next, baseLabel: 'right', shiftSelect: shift);
        return;
      }
      if (logical == LogicalKeyboardKey.home) {
        final next = ctrl ? 0 : _lineStartOffset(_text, cursor);
        moveCursor(
          next: next,
          baseLabel: ctrl ? 'ctrl+home' : 'home',
          shiftSelect: shift,
        );
        return;
      }
      if (logical == LogicalKeyboardKey.end) {
        final next = ctrl ? totalLen : _lineEndOffset(_text, cursor);
        moveCursor(
          next: next,
          baseLabel: ctrl ? 'ctrl+end' : 'end',
          shiftSelect: shift,
        );
        return;
      }
      if (logical == LogicalKeyboardKey.arrowUp) {
        final next = _verticalMoveOffset(_text, cursor, -1);
        moveCursor(next: next, baseLabel: 'up', shiftSelect: shift);
        return;
      }
      if (logical == LogicalKeyboardKey.arrowDown) {
        final next = _verticalMoveOffset(_text, cursor, 1);
        moveCursor(next: next, baseLabel: 'down', shiftSelect: shift);
        return;
      }
      if (logical == LogicalKeyboardKey.backspace) {
        if (selection != null) {
          bridge.deleteRange(
            handle,
            start: selection.start,
            end: selection.end,
          );
          bridge.setCursorOffset(handle, selection.start);
          _clearSelection();
        } else if (cursor > 0) {
          bridge.deleteRange(handle, start: cursor - 1, end: cursor);
          bridge.setCursorOffset(handle, cursor - 1);
        }
        _keyStatus = 'keyboard: backspace';
        _refresh();
        return;
      }
      if (logical == LogicalKeyboardKey.delete) {
        if (selection != null) {
          bridge.deleteRange(
            handle,
            start: selection.start,
            end: selection.end,
          );
          bridge.setCursorOffset(handle, selection.start);
          _clearSelection();
        } else if (cursor < totalLen) {
          bridge.deleteRange(handle, start: cursor, end: cursor + 1);
          bridge.setCursorOffset(handle, cursor);
        }
        _keyStatus = 'keyboard: delete';
        _refresh();
        return;
      }
      if (logical == LogicalKeyboardKey.enter) {
        if (selection != null) {
          bridge.deleteRange(
            handle,
            start: selection.start,
            end: selection.end,
          );
          bridge.setCursorOffset(handle, selection.start);
          _clearSelection();
        }
        bridge.insertText(handle, '\n');
        _keyStatus = 'keyboard: enter';
        _refresh();
        return;
      }

      final character = event.character;
      if (character != null && character.isNotEmpty && !ctrl) {
        if (selection != null) {
          bridge.deleteRange(
            handle,
            start: selection.start,
            end: selection.end,
          );
          bridge.setCursorOffset(handle, selection.start);
          _clearSelection();
        }
        bridge.insertText(handle, character);
        _keyStatus = 'keyboard: char "${character.replaceAll('\n', r'\n')}"';
        _refresh();
      }
    } catch (error) {
      setState(() {
        _keyStatus = 'keyboard error: $error';
      });
    }
  }

  bool _handleViewportShortcut({
    required LogicalKeyboardKey logical,
    required bool ctrl,
  }) {
    if (!_verticalScrollController.hasClients) {
      return false;
    }

    final position = _verticalScrollController.position;
    final page = position.viewportDimension > 0
        ? position.viewportDimension
        : 240;

    if (logical == LogicalKeyboardKey.pageUp) {
      final target = (position.pixels - page).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      _verticalScrollController.jumpTo(target.toDouble());
      setState(() {
        _keyStatus = 'keyboard: pageup (viewport)';
      });
      return true;
    }
    if (logical == LogicalKeyboardKey.pageDown) {
      final target = (position.pixels + page).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      _verticalScrollController.jumpTo(target.toDouble());
      setState(() {
        _keyStatus = 'keyboard: pagedown (viewport)';
      });
      return true;
    }
    if (ctrl && logical == LogicalKeyboardKey.home) {
      _verticalScrollController.jumpTo(position.minScrollExtent);
      setState(() {
        _keyStatus = 'keyboard: ctrl+home (viewport top)';
      });
      return true;
    }
    if (ctrl && logical == LogicalKeyboardKey.end) {
      _verticalScrollController.jumpTo(position.maxScrollExtent);
      setState(() {
        _keyStatus = 'keyboard: ctrl+end (viewport bottom)';
      });
      return true;
    }
    return false;
  }

  int _lineStartOffset(String text, int offset) {
    final clamped = offset.clamp(0, text.length);
    final index = text.lastIndexOf('\n', clamped - 1);
    return index < 0 ? 0 : index + 1;
  }

  int _lineEndOffset(String text, int offset) {
    final clamped = offset.clamp(0, text.length);
    final index = text.indexOf('\n', clamped);
    return index < 0 ? text.length : index;
  }

  int _verticalMoveOffset(String text, int offset, int direction) {
    final clamped = offset.clamp(0, text.length);
    final lineStart = _lineStartOffset(text, clamped);
    final lineEnd = _lineEndOffset(text, clamped);
    final column = clamped - lineStart;

    if (direction < 0) {
      if (lineStart == 0) {
        return clamped;
      }
      final prevEnd = lineStart - 1;
      final prevStart = _lineStartOffset(text, prevEnd);
      return (prevStart + column).clamp(prevStart, prevEnd);
    }

    if (lineEnd >= text.length) {
      return clamped;
    }
    final nextStart = lineEnd + 1;
    final nextEnd = _lineEndOffset(text, nextStart);
    return (nextStart + column).clamp(nextStart, nextEnd);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_status, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: _focusKeyboard,
                  child: const Text('Focus keyboard'),
                ),
                OutlinedButton(
                  onPressed: _reloadMainZig,
                  child: const Text('Reload main.zig'),
                ),
                OutlinedButton(onPressed: _undo, child: const Text('Undo')),
                OutlinedButton(onPressed: _redo, child: const Text('Redo')),
              ],
            ),
            const SizedBox(height: 8),
            SelectableText(
              'state: lines=$_lineCount primary=$_primaryCaret aux=$_auxCount '
              'matches=$_matchCount active=$_activeMatch '
              'selection=${_selectionRange() == null ? 'none' : '${_selectionRange()!.start}-${_selectionRange()!.end}'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            SelectableText(
              _keyStatus,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            SelectableText(
              'shortcuts: ctrl+z/ctrl+y redo, ctrl+a, arrows, shift+arrows, home/end, pageup/down, ctrl+home/end(viewport)',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: KeyboardListener(
                focusNode: _focusNode,
                onKeyEvent: _onEditorKeyEvent,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final contentWidth = (constraints.maxWidth - 16)
                        .clamp(1.0, double.infinity)
                        .toDouble();
                    final lineHeight =
                        12 * 1.2 * MediaQuery.textScalerOf(context).scale(1.0);
                    final contentHeight = math
                        .max(
                          120,
                          (_text.split('\n').length + 1) * lineHeight + 16,
                        )
                        .toDouble();
                    return Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(color: scheme.outlineVariant),
                        borderRadius: BorderRadius.circular(6),
                        color: Colors.black.withValues(alpha: 0.82),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Scrollbar(
                          controller: _verticalScrollController,
                          thumbVisibility: true,
                          child: SingleChildScrollView(
                            controller: _verticalScrollController,
                            padding: const EdgeInsets.all(8),
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: _focusKeyboard,
                              onTapDown: (details) {
                                _focusKeyboard();
                                _setCaretFromTap(
                                  details.localPosition,
                                  contentWidth,
                                );
                              },
                              onPanStart: (details) {
                                _focusKeyboard();
                                _updateSelectionFromDrag(
                                  localPosition: details.localPosition,
                                  contentWidth: contentWidth,
                                  start: true,
                                );
                              },
                              onPanUpdate: (details) {
                                _updateSelectionFromDrag(
                                  localPosition: details.localPosition,
                                  contentWidth: contentWidth,
                                  start: false,
                                );
                              },
                              child: CustomPaint(
                                painter: _EditorTextWithCaretPainter(
                                  text: _text,
                                  primaryOffset: _primaryCaret,
                                  auxiliaryOffsets: _auxOffsets,
                                  selectionStart: _selectionRange()?.start,
                                  selectionEnd: _selectionRange()?.end,
                                  textScaler: MediaQuery.textScalerOf(context),
                                ),
                                child: SizedBox(
                                  width: contentWidth,
                                  height: contentHeight,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditorTextWithCaretPainter extends CustomPainter {
  const _EditorTextWithCaretPainter({
    required this.text,
    required this.primaryOffset,
    required this.auxiliaryOffsets,
    required this.selectionStart,
    required this.selectionEnd,
    required this.textScaler,
  });

  final String text;
  final int primaryOffset;
  final List<int> auxiliaryOffsets;
  final int? selectionStart;
  final int? selectionEnd;
  final TextScaler textScaler;

  static const TextStyle textStyle = TextStyle(
    fontFamily: 'JetBrainsMono Nerd Font Mono',
    fontSize: 12,
    height: 1.2,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final layout = EditorCaretLayout.compute(
      text: text,
      primaryOffset: primaryOffset,
      auxiliaryOffsets: auxiliaryOffsets,
      textScaler: textScaler,
      maxWidth: size.width,
      style: textStyle,
    );

    final selectionFill = Paint()
      ..color = const Color(0xFF64B5F6).withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;
    final start = selectionStart;
    final end = selectionEnd;
    if (start != null && end != null && start != end) {
      final selectionMin = math.min(start, end);
      final selectionMax = math.max(start, end);
      final slices = <({int start, int end})>[];
      var offset = selectionMin;
      while (offset < selectionMax) {
        final boundary = layout.textPainter.getLineBoundary(
          TextPosition(offset: offset),
        );
        final sliceStart = math.max(selectionMin, boundary.start);
        final sliceEnd = math.min(selectionMax, boundary.end);
        if (sliceStart > sliceEnd) {
          offset++;
          continue;
        }
        if (slices.isEmpty ||
            slices.last.start != sliceStart ||
            slices.last.end != sliceEnd) {
          slices.add((start: sliceStart, end: sliceEnd));
        }
        final nextOffset = boundary.end;
        offset = nextOffset > offset ? nextOffset : offset + 1;
      }

      for (final slice in slices) {
        final leftCaret = layout.textPainter.getOffsetForCaret(
          TextPosition(offset: slice.start),
          Rect.zero,
        );
        final rightCaret = layout.textPainter.getOffsetForCaret(
          TextPosition(offset: slice.end),
          Rect.zero,
        );
        final left = math.min(leftCaret.dx, rightCaret.dx);
        final right = math.max(leftCaret.dx, rightCaret.dx);
        final top = leftCaret.dy;
        final bottom = top + layout.lineHeight;
        final rect = (right - left < 1)
            // Empty selected lines/newline-only slices have no visual width.
            // Render a small first-cell stub so selection remains visible.
            ? Rect.fromLTWH(
                0,
                top,
                math.max(6.0, layout.lineHeight * 0.42),
                layout.lineHeight,
              )
            : Rect.fromLTRB(left, top, right, bottom);
        canvas.drawRect(rect, selectionFill);
      }
    }

    layout.textPainter.paint(canvas, Offset.zero);

    final textScale = textScaler.scale(1.0);
    final lineHeight = layout.lineHeight;
    final primaryPaint = Paint()
      ..color = const Color(0xFF4FC3F7)
      ..strokeWidth = 1.5 * textScale.clamp(1.0, 2.0);
    final auxPaint = Paint()
      ..color = const Color(0xFFFFB74D)
      ..strokeWidth = 1.25 * textScale.clamp(1.0, 2.0);

    canvas.drawLine(
      Offset(layout.primaryCaret.dx, layout.primaryCaret.dy),
      Offset(layout.primaryCaret.dx, layout.primaryCaret.dy + lineHeight),
      primaryPaint,
    );

    for (final caret in layout.auxiliaryCarets) {
      canvas.drawLine(
        Offset(caret.dx, caret.dy),
        Offset(caret.dx, caret.dy + lineHeight),
        auxPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _EditorTextWithCaretPainter oldDelegate) {
    return oldDelegate.text != text ||
        oldDelegate.primaryOffset != primaryOffset ||
        oldDelegate.selectionStart != selectionStart ||
        oldDelegate.selectionEnd != selectionEnd ||
        oldDelegate.textScaler != textScaler ||
        oldDelegate.auxiliaryOffsets.join(',') != auxiliaryOffsets.join(',');
  }
}
