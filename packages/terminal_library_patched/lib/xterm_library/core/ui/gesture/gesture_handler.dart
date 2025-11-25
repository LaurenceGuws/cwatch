import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:terminal_library/xterm_library/core/core/mouse/button.dart';
import 'package:terminal_library/xterm_library/core/core/mouse/button_state.dart';
import 'package:terminal_library/xterm_library/core/core/buffer/cell_offset.dart';
import 'package:terminal_library/xterm_library/core/terminal_view.dart';
import 'package:terminal_library/xterm_library/core/ui/controller.dart';
import 'package:terminal_library/xterm_library/core/ui/gesture/gesture_detector.dart';
import 'package:terminal_library/xterm_library/core/ui/pointer_input.dart';
import 'package:terminal_library/xterm_library/core/ui/render.dart';

/// UncompleteDocumentation
class TerminalLibraryFlutterGestureHandler extends StatefulWidget {
  /// UncompleteDocumentation
  const TerminalLibraryFlutterGestureHandler({
    super.key,
    required this.terminalView,
    required this.terminalController,
    this.child,
    this.onTapUp,
    this.onSingleTapUp,
    this.onTapDown,
    this.onSecondaryTapDown,
    this.onSecondaryTapUp,
    this.onTertiaryTapDown,
    this.onTertiaryTapUp,
    this.readOnly = false,
  });

  /// UncompleteDocumentation
  final TerminalLibraryFlutterViewWidgetState terminalView;

  /// UncompleteDocumentation
  final TerminalLibraryFlutterController terminalController;

  /// UncompleteDocumentation
  final Widget? child;

  /// UncompleteDocumentation
  final GestureTapUpCallback? onTapUp;

  /// UncompleteDocumentation
  final GestureTapUpCallback? onSingleTapUp;

  /// UncompleteDocumentation
  final GestureTapDownCallback? onTapDown;

  /// UncompleteDocumentation
  final GestureTapDownCallback? onSecondaryTapDown;

  /// UncompleteDocumentation
  final GestureTapUpCallback? onSecondaryTapUp;

  /// UncompleteDocumentation

  final GestureTapDownCallback? onTertiaryTapDown;

  /// UncompleteDocumentation

  final GestureTapUpCallback? onTertiaryTapUp;

  /// UncompleteDocumentation

  final bool readOnly;

  @override
  State<TerminalLibraryFlutterGestureHandler> createState() =>
      _TerminalLibraryFlutterGestureHandlerState();
}

class _TerminalLibraryFlutterGestureHandlerState
    extends State<TerminalLibraryFlutterGestureHandler> {
  TerminalLibraryFlutterViewWidgetState get terminalView => widget.terminalView;

  RenderTerminalLibraryFlutter get renderTerminalLibraryFlutter =>
      terminalView.renderTerminalLibraryFlutter;

  CellOffset? _dragStartCell;
  LongPressStartDetails? _lastLongPressStartDetails;
  CellOffset? _lastAnchorCell;

  @override
  Widget build(BuildContext context) {
    return TerminalLibraryFlutterGestureDetector(
      onTapUp: widget.onTapUp,
      onSingleTapUp: onSingleTapUp,
      onTapDown: onTapDown,
      onSecondaryTapDown: onSecondaryTapDown,
      onSecondaryTapUp: onSecondaryTapUp,
      onTertiaryTapDown: onSecondaryTapDown,
      onTertiaryTapUp: onSecondaryTapUp,
      onLongPressStart: onLongPressStart,
      onLongPressMoveUpdate: onLongPressMoveUpdate,
      // onLongPressUp: onLongPressUp,
      onDragStart: onDragStart,
      onDragUpdate: onDragUpdate,
      onDoubleTapDown: onDoubleTapDown,
      child: widget.child,
    );
  }

  bool get _shouldSendTapEvent =>
      !widget.readOnly &&
      widget.terminalController.shouldSendPointerInput(PointerInput.tap);

  void _tapDown(
    GestureTapDownCallback? callback,
    TapDownDetails details,
    TerminalLibraryFlutterMouseButton button, {
    bool forceCallback = false,
  }) {
    // Check if the terminal should and can handle the tap down event.
    var handled = false;
    if (_shouldSendTapEvent) {
      handled = renderTerminalLibraryFlutter.mouseEvent(
        button,
        TerminalLibraryFlutterMouseButtonState.down,
        details.localPosition,
      );
    }
    // If the event was not handled by the terminal, use the supplied callback.
    if (!handled || forceCallback) {
      callback?.call(details);
    }
  }

  void _tapUp(
    GestureTapUpCallback? callback,
    TapUpDetails details,
    TerminalLibraryFlutterMouseButton button, {
    bool forceCallback = false,
  }) {
    // Check if the terminal should and can handle the tap up event.
    var handled = false;
    if (_shouldSendTapEvent) {
      handled = renderTerminalLibraryFlutter.mouseEvent(
        button,
        TerminalLibraryFlutterMouseButtonState.up,
        details.localPosition,
      );
    }
    // If the event was not handled by the terminal, use the supplied callback.
    if (!handled || forceCallback) {
      callback?.call(details);
    }
  }

  void onTapDown(TapDownDetails details) {
    final cell = renderTerminalLibraryFlutter.getCellOffset(
      details.localPosition,
    );
    final shiftPressed = HardwareKeyboard.instance.logicalKeysPressed
        .any((key) => key == LogicalKeyboardKey.shiftLeft || key == LogicalKeyboardKey.shiftRight);

    if (shiftPressed && _lastAnchorCell != null) {
      renderTerminalLibraryFlutter.selectCharactersFromCells(
        _lastAnchorCell!,
        cell,
      );
      return;
    }

    // onTapDown is special, as it will always call the supplied callback.
    // The TerminalLibraryFlutterViewWidget depends on it to bring the terminal into focus.
    _tapDown(
      widget.onTapDown,
      details,
      TerminalLibraryFlutterMouseButton.left,
      forceCallback: true,
    );
    _lastAnchorCell = cell;
  }

  void onSingleTapUp(TapUpDetails details) {
    _tapUp(
        widget.onSingleTapUp, details, TerminalLibraryFlutterMouseButton.left);
  }

  void onSecondaryTapDown(TapDownDetails details) {
    _tapDown(widget.onSecondaryTapDown, details,
        TerminalLibraryFlutterMouseButton.right);
  }

  void onSecondaryTapUp(TapUpDetails details) {
    _tapUp(widget.onSecondaryTapUp, details,
        TerminalLibraryFlutterMouseButton.right);
  }

  void onTertiaryTapDown(TapDownDetails details) {
    _tapDown(widget.onTertiaryTapDown, details,
        TerminalLibraryFlutterMouseButton.middle);
  }

  void onTertiaryTapUp(TapUpDetails details) {
    _tapUp(widget.onTertiaryTapUp, details,
        TerminalLibraryFlutterMouseButton.right);
  }

  void onDoubleTapDown(TapDownDetails details) {
    renderTerminalLibraryFlutter.selectWord(details.localPosition);
  }

  void onLongPressStart(LongPressStartDetails details) {
    _lastLongPressStartDetails = details;
    renderTerminalLibraryFlutter.selectWord(details.localPosition);
  }

  void onLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    renderTerminalLibraryFlutter.selectWord(
      _lastLongPressStartDetails!.localPosition,
      details.localPosition,
    );
  }

  // void onLongPressUp() {}

  void onDragStart(DragStartDetails details) {
    _dragStartCell = renderTerminalLibraryFlutter.getCellOffset(
      details.localPosition,
    );
    _lastAnchorCell = _dragStartCell;

    details.kind == PointerDeviceKind.mouse
        ? renderTerminalLibraryFlutter
            .selectCharactersFromCells(_dragStartCell!)
        : renderTerminalLibraryFlutter.selectWord(details.localPosition);
  }

  void onDragUpdate(DragUpdateDetails details) {
    if (_dragStartCell == null) return;
    final toCell =
        renderTerminalLibraryFlutter.getCellOffset(details.localPosition);
    renderTerminalLibraryFlutter.selectCharactersFromCells(
      _dragStartCell!,
      toCell,
    );
  }
}
