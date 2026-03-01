import 'dart:async';
import 'dart:ffi' show Pointer;
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:cwatch/model/services_infra/logging/app_logger.dart';
import 'package:cwatch/model/services_infra/settings/app_settings_controller.dart';
import 'package:cwatch/model/services_infra/zide/zide_editor_ffi_bridge.dart';
import 'support/editor_caret_layout.dart';
import 'support/editor_text_navigation.dart';
import 'support/overlay_scrollbar.dart';
import 'support/zide_font_defaults.dart';

class ZideEditorCanvas extends StatefulWidget {
  const ZideEditorCanvas({super.key, required this.settingsController});

  final AppSettingsController settingsController;

  @override
  State<ZideEditorCanvas> createState() => _ZideEditorCanvasState();
}

class _ZideEditorCanvasState extends State<ZideEditorCanvas> {
  static const String _logTag = 'ZideMigrationEditor';
  ZideEditorFfiBridge? _bridge;
  Pointer<ZideEditorHandle>? _handle;
  final FocusNode _focusNode = FocusNode(debugLabel: 'zide_editor_canvas');
  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();
  double _editorContentWidth = 0;
  TextPainter? _cachedTextPainter;
  String _cachedPainterText = '';
  double _cachedPainterWidth = -1;
  double _cachedPainterScale = -1;
  bool _dragSelectionFrameScheduled = false;
  int? _pendingDragSelectionCaret;
  int _dragEventsSinceLog = 0;
  int _dragFlushesSinceLog = 0;
  int _dragLastLogMs = 0;

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
    _horizontalScrollController.dispose();
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
    _refresh(revealCaret: true);
  }

  void _refresh({bool revealCaret = false}) {
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
      if (revealCaret) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          _ensurePrimaryCaretVisible();
        });
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

  void _undo() {
    final bridge = _bridge;
    final handle = _handle;
    if (bridge == null || handle == null) {
      return;
    }
    bridge.undo(handle);
    _refresh(revealCaret: true);
  }

  void _redo() {
    final bridge = _bridge;
    final handle = _handle;
    if (bridge == null || handle == null) {
      return;
    }
    bridge.redo(handle);
    _refresh(revealCaret: true);
  }

  void _focusKeyboard() {
    _focusNode.requestFocus();
    setState(() {
      _keyStatus = 'keyboard: focused';
    });
  }

  ({int start, int end})? _selectionRange() {
    return EditorTextNavigation.normalizedSelectionRange(
      anchor: _selectionAnchor,
      focus: _selectionFocus,
      maxLength: _text.length,
    );
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
      final offset = _offsetFromPointFast(
        point: textPoint,
        contentWidth: contentWidth,
      );
      bridge.setCursorOffset(handle, offset);
      _clearSelection();
      _keyStatus = 'keyboard: click caret=$offset';
      _refresh(revealCaret: true);
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
    final offset = _offsetFromPointFast(
      point: textPoint,
      contentWidth: contentWidth,
    );
    if (start || _selectionAnchor == null) {
      _selectionAnchor = offset;
      _selectionFocus = offset;
    } else {
      _selectionFocus = offset;
    }
    _dragEventsSinceLog++;
    _pendingDragSelectionCaret = _selectionFocus ?? offset;
    _maybeLogDragPerf();
    _scheduleDragSelectionRepaint();
  }

  void _scheduleDragSelectionRepaint() {
    if (_dragSelectionFrameScheduled) {
      return;
    }
    _dragSelectionFrameScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _dragSelectionFrameScheduled = false;
      _flushPendingDragSelectionRepaint();
    });
  }

  void _flushPendingDragSelectionRepaint() {
    final pending = _pendingDragSelectionCaret;
    if (pending == null || !mounted) {
      return;
    }
    _dragFlushesSinceLog++;
    _pendingDragSelectionCaret = null;
    setState(() {
      _primaryCaret = pending;
      _keyStatus = 'keyboard: drag selection';
    });
    _maybeLogDragPerf();
  }

  void _maybeLogDragPerf() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_dragLastLogMs == 0) {
      _dragLastLogMs = now;
      return;
    }
    if (now - _dragLastLogMs < 1000) {
      return;
    }
    if (_dragEventsSinceLog == 0 && _dragFlushesSinceLog == 0) {
      _dragLastLogMs = now;
      return;
    }
    AppLogger().debug(
      'dragPerf events=$_dragEventsSinceLog flushes=$_dragFlushesSinceLog '
      'frameScheduled=$_dragSelectionFrameScheduled pending=${_pendingDragSelectionCaret != null}',
      tag: _logTag,
    );
    AppLogger.emitPerformanceSample(
      source: 'zide_editor',
      metric: 'drag_events_per_sec',
      value: _dragEventsSinceLog.toDouble(),
      attributes: {'flushes': _dragFlushesSinceLog},
    );
    AppLogger.emitPerformanceSample(
      source: 'zide_editor',
      metric: 'drag_flushes_per_sec',
      value: _dragFlushesSinceLog.toDouble(),
      attributes: {'events': _dragEventsSinceLog},
    );
    _dragEventsSinceLog = 0;
    _dragFlushesSinceLog = 0;
    _dragLastLogMs = now;
  }

  TextPainter _ensureCachedTextPainter({
    required double contentWidth,
    required TextScaler textScaler,
  }) {
    final normalizedText = _text.isEmpty ? ' ' : _text;
    final scale = textScaler.scale(1.0);
    final shouldRebuild =
        _cachedTextPainter == null ||
        _cachedPainterText != normalizedText ||
        (_cachedPainterWidth - contentWidth).abs() > 0.5 ||
        (_cachedPainterScale - scale).abs() > 0.001;

    if (shouldRebuild) {
      final painter = TextPainter(
        text: TextSpan(
          text: normalizedText,
          style: _EditorTextWithCaretPainter.textStyle,
        ),
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
        maxLines: null,
      )..layout(maxWidth: contentWidth);
      _cachedTextPainter = painter;
      _cachedPainterText = normalizedText;
      _cachedPainterWidth = contentWidth;
      _cachedPainterScale = scale;
    }

    return _cachedTextPainter!;
  }

  int _offsetFromPointFast({
    required Offset point,
    required double contentWidth,
  }) {
    final painter = _ensureCachedTextPainter(
      contentWidth: contentWidth,
      textScaler: MediaQuery.textScalerOf(context),
    );
    final position = painter.getPositionForOffset(point);
    return position.offset.clamp(0, _text.length);
  }

  bool _onEditorKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) {
      return false;
    }
    final bridge = _bridge;
    final handle = _handle;
    if (bridge == null || handle == null) {
      return false;
    }

    try {
      final logical = event.logicalKey;
      final ctrl = HardwareKeyboard.instance.isControlPressed;
      final shift = HardwareKeyboard.instance.isShiftPressed;

      if (_handleViewportShortcut(logical: logical, ctrl: ctrl)) {
        return true;
      }

      if (ctrl && logical == LogicalKeyboardKey.keyZ) {
        bridge.undo(handle);
        _keyStatus = 'keyboard: ctrl+z';
        _refresh(revealCaret: true);
        return true;
      }
      if (ctrl &&
          (logical == LogicalKeyboardKey.keyY ||
              (HardwareKeyboard.instance.isShiftPressed &&
                  logical == LogicalKeyboardKey.keyZ))) {
        bridge.redo(handle);
        _keyStatus = 'keyboard: redo';
        _refresh(revealCaret: true);
        return true;
      }
      if (ctrl && logical == LogicalKeyboardKey.keyA) {
        final totalLen = bridge.totalLength(handle);
        _selectionAnchor = 0;
        _selectionFocus = totalLen;
        bridge.setCursorOffset(handle, totalLen);
        _keyStatus = 'keyboard: ctrl+a';
        _refresh(revealCaret: true);
        return true;
      }
      if (ctrl && logical == LogicalKeyboardKey.keyC) {
        unawaited(_copySelectionToClipboard());
        return true;
      }
      if (ctrl && logical == LogicalKeyboardKey.keyX) {
        unawaited(_cutSelectionToClipboard());
        return true;
      }
      if (ctrl && logical == LogicalKeyboardKey.keyV) {
        unawaited(_pasteFromClipboard());
        return true;
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
        _refresh(revealCaret: true);
      }

      if (logical == LogicalKeyboardKey.arrowLeft) {
        final next = ctrl
            ? EditorTextNavigation.previousWordOffset(_text, cursor)
            : (cursor > 0 ? cursor - 1 : 0);
        moveCursor(next: next, baseLabel: 'left', shiftSelect: shift);
        return true;
      }
      if (logical == LogicalKeyboardKey.arrowRight) {
        final next = ctrl
            ? EditorTextNavigation.nextWordOffset(_text, cursor)
            : (cursor < totalLen ? cursor + 1 : totalLen);
        moveCursor(next: next, baseLabel: 'right', shiftSelect: shift);
        return true;
      }
      if (logical == LogicalKeyboardKey.home) {
        final next = ctrl
            ? 0
            : EditorTextNavigation.lineStartOffset(_text, cursor);
        moveCursor(
          next: next,
          baseLabel: ctrl ? 'ctrl+home' : 'home',
          shiftSelect: shift,
        );
        return true;
      }
      if (logical == LogicalKeyboardKey.end) {
        final next = ctrl
            ? totalLen
            : EditorTextNavigation.lineEndOffset(_text, cursor);
        moveCursor(
          next: next,
          baseLabel: ctrl ? 'ctrl+end' : 'end',
          shiftSelect: shift,
        );
        return true;
      }
      if (logical == LogicalKeyboardKey.arrowUp) {
        final next = EditorTextNavigation.verticalMoveOffset(_text, cursor, -1);
        moveCursor(next: next, baseLabel: 'up', shiftSelect: shift);
        return true;
      }
      if (logical == LogicalKeyboardKey.arrowDown) {
        final next = EditorTextNavigation.verticalMoveOffset(_text, cursor, 1);
        moveCursor(next: next, baseLabel: 'down', shiftSelect: shift);
        return true;
      }
      if (logical == LogicalKeyboardKey.escape) {
        _clearSelection();
        _keyStatus = 'keyboard: escape (clear selection)';
        _refresh(revealCaret: true);
        return true;
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
        } else if (ctrl) {
          final range = EditorTextNavigation.previousWordDeleteRange(
            _text,
            cursor,
          );
          if (range != null) {
            bridge.deleteRange(handle, start: range.start, end: range.end);
            bridge.setCursorOffset(handle, range.start);
          }
        } else if (cursor > 0) {
          bridge.deleteRange(handle, start: cursor - 1, end: cursor);
          bridge.setCursorOffset(handle, cursor - 1);
        }
        _keyStatus = ctrl ? 'keyboard: ctrl+backspace' : 'keyboard: backspace';
        _refresh(revealCaret: true);
        return true;
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
        } else if (ctrl) {
          final range = EditorTextNavigation.nextWordDeleteRange(_text, cursor);
          if (range != null) {
            bridge.deleteRange(handle, start: range.start, end: range.end);
            bridge.setCursorOffset(handle, range.start);
          }
        } else if (cursor < totalLen) {
          bridge.deleteRange(handle, start: cursor, end: cursor + 1);
          bridge.setCursorOffset(handle, cursor);
        }
        _keyStatus = ctrl ? 'keyboard: ctrl+delete' : 'keyboard: delete';
        _refresh(revealCaret: true);
        return true;
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
        _refresh(revealCaret: true);
        return true;
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
        _refresh(revealCaret: true);
        return true;
      }
    } catch (error) {
      setState(() {
        _keyStatus = 'keyboard error: $error';
      });
    }
    return false;
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

  Future<void> _copySelectionToClipboard() async {
    final selection = _selectionRange();
    if (selection == null) {
      if (!mounted) {
        return;
      }
      setState(() {
        _keyStatus = 'keyboard: ctrl+c (no selection)';
      });
      return;
    }
    final slice = _text.substring(selection.start, selection.end);
    await Clipboard.setData(ClipboardData(text: slice));
    if (!mounted) {
      return;
    }
    setState(() {
      _keyStatus = 'keyboard: ctrl+c';
    });
  }

  Future<void> _cutSelectionToClipboard() async {
    final bridge = _bridge;
    final handle = _handle;
    final selection = _selectionRange();
    if (bridge == null || handle == null || selection == null) {
      if (!mounted) {
        return;
      }
      setState(() {
        _keyStatus = 'keyboard: ctrl+x (no selection)';
      });
      return;
    }
    final slice = _text.substring(selection.start, selection.end);
    await Clipboard.setData(ClipboardData(text: slice));
    bridge.deleteRange(handle, start: selection.start, end: selection.end);
    bridge.setCursorOffset(handle, selection.start);
    _clearSelection();
    _keyStatus = 'keyboard: ctrl+x';
    _refresh(revealCaret: true);
  }

  Future<void> _pasteFromClipboard() async {
    final bridge = _bridge;
    final handle = _handle;
    if (bridge == null || handle == null) {
      return;
    }
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.isEmpty) {
      if (!mounted) {
        return;
      }
      setState(() {
        _keyStatus = 'keyboard: ctrl+v (clipboard empty)';
      });
      return;
    }
    final selection = _selectionRange();
    if (selection != null) {
      bridge.deleteRange(handle, start: selection.start, end: selection.end);
      bridge.setCursorOffset(handle, selection.start);
      _clearSelection();
    }
    bridge.insertText(handle, text);
    _keyStatus = 'keyboard: ctrl+v';
    _refresh(revealCaret: true);
  }

  void _ensurePrimaryCaretVisible() {
    if (_editorContentWidth <= 0 ||
        !_verticalScrollController.hasClients ||
        !_horizontalScrollController.hasClients) {
      return;
    }

    final layout = EditorCaretLayout.compute(
      text: _text,
      primaryOffset: _primaryCaret,
      auxiliaryOffsets: const [],
      textScaler: MediaQuery.textScalerOf(context),
      maxWidth: _editorContentWidth,
      style: _EditorTextWithCaretPainter.textStyle,
    );

    final position = _verticalScrollController.position;
    final horizontalPosition = _horizontalScrollController.position;
    const contentTopPadding = 8.0;
    const contentLeftPadding = 8.0;
    const margin = 6.0;
    final caretLeft = layout.primaryCaret.dx + contentLeftPadding;
    final caretRight = caretLeft + 2.0;
    final caretTop = layout.primaryCaret.dy + contentTopPadding;
    final caretBottom = caretTop + layout.lineHeight;
    final viewTop = position.pixels;
    final viewBottom = viewTop + position.viewportDimension;
    final viewLeft = horizontalPosition.pixels;
    final viewRight = viewLeft + horizontalPosition.viewportDimension;

    if (caretLeft < viewLeft + margin) {
      final target = (caretLeft - margin).clamp(
        horizontalPosition.minScrollExtent,
        horizontalPosition.maxScrollExtent,
      );
      _horizontalScrollController.jumpTo(target.toDouble());
    } else if (caretRight > viewRight - margin) {
      final target =
          (caretRight - horizontalPosition.viewportDimension + margin).clamp(
            horizontalPosition.minScrollExtent,
            horizontalPosition.maxScrollExtent,
          );
      _horizontalScrollController.jumpTo(target.toDouble());
    }

    if (caretTop < viewTop + margin) {
      final target = (caretTop - margin).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      _verticalScrollController.jumpTo(target.toDouble());
      return;
    }

    if (caretBottom > viewBottom - margin) {
      final target = (caretBottom - position.viewportDimension + margin).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      _verticalScrollController.jumpTo(target.toDouble());
    }
  }

  double _measureContentWidth({
    required String text,
    required TextScaler textScaler,
    required double minWidth,
  }) {
    final lines = text.split('\n');
    final painter = TextPainter(
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
      maxLines: 1,
    );

    var maxLineWidth = 0.0;
    for (final line in lines) {
      final sample = line.isEmpty ? ' ' : line;
      painter.text = TextSpan(
        text: sample,
        style: _EditorTextWithCaretPainter.textStyle,
      );
      painter.layout(minWidth: 0, maxWidth: double.infinity);
      if (painter.width > maxLineWidth) {
        maxLineWidth = painter.width;
      }
    }
    return math.max(minWidth, maxLineWidth + 16);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, rootConstraints) {
        final compactHeader = rootConstraints.maxHeight < 300;
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
                SelectableText(
                  _status,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 6),
                if (!compactHeader)
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
                      OutlinedButton(
                        onPressed: _undo,
                        child: const Text('Undo'),
                      ),
                      OutlinedButton(
                        onPressed: _redo,
                        child: const Text('Redo'),
                      ),
                    ],
                  ),
                if (!compactHeader) const SizedBox(height: 8),
                if (!compactHeader)
                  SelectableText(
                    'state: lines=$_lineCount primary=$_primaryCaret aux=$_auxCount '
                    'matches=$_matchCount active=$_activeMatch '
                    'selection=${_selectionRange() == null ? 'none' : '${_selectionRange()!.start}-${_selectionRange()!.end}'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                if (!compactHeader) const SizedBox(height: 4),
                SelectableText(
                  _keyStatus,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (!compactHeader) const SizedBox(height: 4),
                if (!compactHeader)
                  SelectableText(
                    'shortcuts: ctrl+z/ctrl+y redo, ctrl+a, arrows, ctrl+left/right words, '
                    'shift+arrows select, home/end, pageup/down, ctrl+home/end(viewport), '
                    'ctrl+backspace/delete, ctrl+c/x/v',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                const SizedBox(height: 8),
                Expanded(
                  child: Focus(
                    focusNode: _focusNode,
                    onKeyEvent: (_, event) {
                      return _onEditorKeyEvent(event)
                          ? KeyEventResult.handled
                          : KeyEventResult.ignored;
                    },
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final viewportContentWidth = (constraints.maxWidth - 16)
                            .clamp(1.0, double.infinity)
                            .toDouble();
                        final contentWidth = _measureContentWidth(
                          text: _text,
                          textScaler: MediaQuery.textScalerOf(context),
                          minWidth: viewportContentWidth,
                        );
                        _editorContentWidth = contentWidth;
                        final lineHeight =
                            12 *
                            1.2 *
                            MediaQuery.textScalerOf(context).scale(1.0);
                        final cachedPainter = _ensureCachedTextPainter(
                          contentWidth: contentWidth,
                          textScaler: MediaQuery.textScalerOf(context),
                        );
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
                            child: Listener(
                              onPointerSignal: (signal) {
                                if (signal is! PointerScrollEvent) {
                                  return;
                                }
                                if (!_horizontalScrollController.hasClients) {
                                  return;
                                }
                                var deltaX = signal.scrollDelta.dx;
                                if (deltaX == 0 &&
                                    HardwareKeyboard.instance.isShiftPressed) {
                                  deltaX = signal.scrollDelta.dy;
                                }
                                if (deltaX == 0) {
                                  return;
                                }
                                final position =
                                    _horizontalScrollController.position;
                                final target = (position.pixels + deltaX).clamp(
                                  position.minScrollExtent,
                                  position.maxScrollExtent,
                                );
                                _horizontalScrollController.jumpTo(
                                  target.toDouble(),
                                );
                              },
                              child: Scrollbar(
                                controller: _horizontalScrollController,
                                thumbVisibility: true,
                                notificationPredicate: (notification) =>
                                    notification.metrics.axis ==
                                    Axis.horizontal,
                                child: SingleChildScrollView(
                                  controller: _horizontalScrollController,
                                  scrollDirection: Axis.horizontal,
                                  child: SizedBox(
                                    width: contentWidth + 16,
                                    child: Stack(
                                      children: [
                                        Positioned.fill(
                                          child: SingleChildScrollView(
                                            controller:
                                                _verticalScrollController,
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
                                                  localPosition:
                                                      details.localPosition,
                                                  contentWidth: contentWidth,
                                                  start: true,
                                                );
                                              },
                                              onPanUpdate: (details) {
                                                _updateSelectionFromDrag(
                                                  localPosition:
                                                      details.localPosition,
                                                  contentWidth: contentWidth,
                                                  start: false,
                                                );
                                              },
                                              onPanEnd: (_) {
                                                _flushPendingDragSelectionRepaint();
                                                final bridge = _bridge;
                                                final handle = _handle;
                                                final focus = _selectionFocus;
                                                if (bridge != null &&
                                                    handle != null &&
                                                    focus != null) {
                                                  bridge.setCursorOffset(
                                                    handle,
                                                    focus,
                                                  );
                                                }
                                                _refresh(revealCaret: true);
                                              },
                                              child: CustomPaint(
                                                painter:
                                                    _EditorTextWithCaretPainter(
                                                      text: _text,
                                                      primaryOffset:
                                                          _primaryCaret,
                                                      auxiliaryOffsets:
                                                          _auxOffsets,
                                                      selectionStart:
                                                          _selectionRange()
                                                              ?.start,
                                                      selectionEnd:
                                                          _selectionRange()
                                                              ?.end,
                                                      textPainter:
                                                          cachedPainter,
                                                      lineHeight: cachedPainter
                                                          .preferredLineHeight,
                                                    ),
                                                child: SizedBox(
                                                  width: contentWidth,
                                                  height: contentHeight,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        if (_verticalScrollController
                                            .hasClients)
                                          Positioned(
                                            right: 0,
                                            top: 0,
                                            bottom: 0,
                                            child: OverlayScrollbar(
                                              viewportExtent:
                                                  _verticalScrollController
                                                      .position
                                                      .viewportDimension,
                                              contentExtent:
                                                  (_verticalScrollController
                                                      .position
                                                      .maxScrollExtent +
                                                  _verticalScrollController
                                                      .position
                                                      .viewportDimension),
                                              offset: _verticalScrollController
                                                  .position
                                                  .pixels,
                                              onOffsetChanged: (value) {
                                                if (!_verticalScrollController
                                                    .hasClients) {
                                                  return;
                                                }
                                                final position =
                                                    _verticalScrollController
                                                        .position;
                                                final target = value.clamp(
                                                  position.minScrollExtent,
                                                  position.maxScrollExtent,
                                                );
                                                _verticalScrollController
                                                    .jumpTo(target.toDouble());
                                              },
                                              onStepUp: () {
                                                if (!_verticalScrollController
                                                    .hasClients) {
                                                  return;
                                                }
                                                final position =
                                                    _verticalScrollController
                                                        .position;
                                                final step =
                                                    position.viewportDimension;
                                                final target =
                                                    (position.pixels - step)
                                                        .clamp(
                                                          position
                                                              .minScrollExtent,
                                                          position
                                                              .maxScrollExtent,
                                                        );
                                                _verticalScrollController
                                                    .jumpTo(target.toDouble());
                                              },
                                              onStepDown: () {
                                                if (!_verticalScrollController
                                                    .hasClients) {
                                                  return;
                                                }
                                                final position =
                                                    _verticalScrollController
                                                        .position;
                                                final step =
                                                    position.viewportDimension;
                                                final target =
                                                    (position.pixels + step)
                                                        .clamp(
                                                          position
                                                              .minScrollExtent,
                                                          position
                                                              .maxScrollExtent,
                                                        );
                                                _verticalScrollController
                                                    .jumpTo(target.toDouble());
                                              },
                                            ),
                                          ),
                                      ],
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
      },
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
    required this.textPainter,
    required this.lineHeight,
  });

  final String text;
  final int primaryOffset;
  final List<int> auxiliaryOffsets;
  final int? selectionStart;
  final int? selectionEnd;
  final TextPainter textPainter;
  final double lineHeight;

  static const TextStyle textStyle = TextStyle(
    fontFamily: ZideFontDefaults.primaryFamily,
    fontFamilyFallback: [ZideFontDefaults.monoFallbackFamily],
    fontSize: 12,
    height: 1.2,
  );

  @override
  void paint(Canvas canvas, Size size) {
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
        final boundary = textPainter.getLineBoundary(
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
        final leftCaret = textPainter.getOffsetForCaret(
          TextPosition(offset: slice.start),
          Rect.zero,
        );
        final rightCaret = textPainter.getOffsetForCaret(
          TextPosition(offset: slice.end),
          Rect.zero,
        );
        final left = math.min(leftCaret.dx, rightCaret.dx);
        final right = math.max(leftCaret.dx, rightCaret.dx);
        final top = leftCaret.dy;
        final bottom = top + lineHeight;
        final rect = (right - left < 1)
            // Empty selected lines/newline-only slices have no visual width.
            // Render a small first-cell stub so selection remains visible.
            ? Rect.fromLTWH(
                0,
                top,
                math.max(6.0, lineHeight * 0.42),
                lineHeight,
              )
            : Rect.fromLTRB(left, top, right, bottom);
        canvas.drawRect(rect, selectionFill);
      }
    }

    textPainter.paint(canvas, Offset.zero);

    final textScale = textPainter.textScaler.scale(1.0);
    final primaryPaint = Paint()
      ..color = const Color(0xFF4FC3F7)
      ..strokeWidth = 1.5 * textScale.clamp(1.0, 2.0);
    final auxPaint = Paint()
      ..color = const Color(0xFFFFB74D)
      ..strokeWidth = 1.25 * textScale.clamp(1.0, 2.0);

    final safePrimary = primaryOffset.clamp(0, text.length);
    final primaryCaret = textPainter.getOffsetForCaret(
      TextPosition(offset: safePrimary),
      Rect.zero,
    );
    canvas.drawLine(
      Offset(primaryCaret.dx, primaryCaret.dy),
      Offset(primaryCaret.dx, primaryCaret.dy + lineHeight),
      primaryPaint,
    );

    for (final offset in auxiliaryOffsets) {
      final safeOffset = offset.clamp(0, text.length);
      final caret = textPainter.getOffsetForCaret(
        TextPosition(offset: safeOffset),
        Rect.zero,
      );
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
        oldDelegate.textPainter != textPainter ||
        oldDelegate.lineHeight != lineHeight ||
        oldDelegate.auxiliaryOffsets.join(',') != auxiliaryOffsets.join(',');
  }
}
