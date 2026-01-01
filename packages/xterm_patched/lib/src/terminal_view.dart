import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:cwatch/services/logging/app_logger.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:xterm/src/core/buffer/cell_offset.dart';
import 'package:xterm/src/core/buffer/range.dart';

import 'package:xterm/src/core/input/keys.dart';
import 'package:xterm/src/terminal.dart';
import 'package:xterm/src/ui/controller.dart';
import 'package:xterm/src/ui/cursor_type.dart';
import 'package:xterm/src/ui/custom_text_edit.dart';
import 'package:xterm/src/ui/gesture/gesture_handler.dart';
import 'package:xterm/src/ui/input_map.dart';
import 'package:xterm/src/ui/keyboard_listener.dart';
import 'package:xterm/src/ui/keyboard_visibility.dart';
import 'package:xterm/src/ui/render.dart';
import 'package:xterm/src/ui/scroll_handler.dart';
import 'package:xterm/src/ui/shortcut/actions.dart';
import 'package:xterm/src/ui/shortcut/shortcuts.dart';
import 'package:xterm/src/ui/terminal_text_style.dart';
import 'package:xterm/src/ui/terminal_theme.dart';
import 'package:xterm/src/ui/themes.dart';

class TerminalView extends StatefulWidget {
  const TerminalView(
    this.terminal, {
    super.key,
    this.controller,
    this.theme = TerminalThemes.defaultTheme,
    this.textStyle = const TerminalStyle(),
    this.textScaler,
    this.padding,
    this.scrollController,
    this.autoResize = true,
    this.backgroundOpacity = 1,
    this.focusNode,
    this.autofocus = false,
    this.onTapUp,
    this.onSecondaryTapDown,
    this.onSecondaryTapUp,
    this.mouseCursor = SystemMouseCursors.text,
    this.keyboardType = TextInputType.emailAddress,
    this.keyboardAppearance = Brightness.dark,
    this.cursorType = TerminalCursorType.block,
    this.alwaysShowCursor = false,
    this.minFontSize = 8,
    this.maxFontSize = 32,
    this.enablePinchZoom = true,
    this.onFontSizeChange,
    this.deleteDetection = false,
    this.shortcuts,
    this.onKeyEvent,
    this.readOnly = false,
    this.hardwareKeyboardOnly = false,
    this.simulateScroll = true,
  });

  /// The underlying terminal that this widget renders.
  final Terminal terminal;

  final TerminalController? controller;

  /// The theme to use for this terminal.
  final TerminalTheme theme;

  /// The style to use for painting characters.
  final TerminalStyle textStyle;

  final TextScaler? textScaler;

  /// Padding around the inner [Scrollable] widget.
  final EdgeInsets? padding;

  /// Scroll controller for the inner [Scrollable] widget.
  final ScrollController? scrollController;

  /// Should this widget automatically notify the underlying terminal when its
  /// size changes. [true] by default.
  final bool autoResize;

  /// Opacity of the terminal background. Set to 0 to make the terminal
  /// background transparent.
  final double backgroundOpacity;

  /// An optional focus node to use as the focus node for this widget.
  final FocusNode? focusNode;

  /// True if this widget will be selected as the initial focus when no other
  /// node in its scope is currently focused.
  final bool autofocus;

  /// Callback for when the user taps on the terminal.
  final void Function(TapUpDetails, CellOffset)? onTapUp;

  /// Function called when the user taps on the terminal with a secondary
  /// button.
  final void Function(TapDownDetails, CellOffset)? onSecondaryTapDown;

  /// Function called when the user stops holding down a secondary button.
  final void Function(TapUpDetails, CellOffset)? onSecondaryTapUp;

  /// The mouse cursor for mouse pointers that are hovering over the terminal.
  /// [SystemMouseCursors.text] by default.
  final MouseCursor mouseCursor;

  /// The type of information for which to optimize the text input control.
  /// [TextInputType.emailAddress] by default.
  final TextInputType keyboardType;

  /// The appearance of the keyboard. [Brightness.dark] by default.
  ///
  /// This setting is only honored on iOS devices.
  final Brightness keyboardAppearance;

  /// The type of cursor to use. [TerminalCursorType.block] by default.
  final TerminalCursorType cursorType;

  /// Whether to always show the cursor. This is useful for debugging.
  /// [false] by default.
  final bool alwaysShowCursor;

  /// Optional callback when the terminal font size changes (e.g. via pinch).
  final ValueChanged<double>? onFontSizeChange;

  /// Minimum and maximum terminal font sizes.
  final double minFontSize;

  final double maxFontSize;

  /// Whether pinch-to-zoom gestures are enabled.
  final bool enablePinchZoom;

  /// Workaround to detect delete key for platforms and IMEs that does not
  /// emit hardware delete event. Prefered on mobile platforms. [false] by
  /// default.
  final bool deleteDetection;

  /// Shortcuts for this terminal. This has higher priority than input handler
  /// of the terminal If not provided, [defaultTerminalShortcuts] will be used.
  final Map<ShortcutActivator, Intent>? shortcuts;

  /// Keyboard event handler of the terminal. This has higher priority than
  /// [shortcuts] and input handler of the terminal.
  final FocusOnKeyEventCallback? onKeyEvent;

  /// True if no input should send to the terminal.
  final bool readOnly;

  /// True if only hardware keyboard events should be used as input. This will
  /// also prevent any on-screen keyboard to be shown.
  final bool hardwareKeyboardOnly;

  /// If true, when the terminal is in alternate buffer (for example running
  /// vim, man, etc), if the application does not declare that it can handle
  /// scrolling, the terminal will simulate scrolling by sending up/down arrow
  /// keys to the application. This is standard behavior for most terminal
  /// emulators. True by default.
  final bool simulateScroll;

  @override
  State<TerminalView> createState() => TerminalViewState();
}

class TerminalViewState extends State<TerminalView> {
  late FocusNode _focusNode;

  late final ShortcutManager _shortcutManager;

  final _customTextEditKey = GlobalKey<CustomTextEditState>();

  final _scrollableKey = GlobalKey<ScrollableState>();

  final _viewportKey = GlobalKey();

  String? _composingText;

  late TerminalController _controller;

  late ScrollController _scrollController;

  static const double _selectionHandleSize = 12;
  bool _draggingSelectionHandle = false;
  bool _draggingStartHandle = false;
  CellOffset? _dragStartBaseCell;
  CellOffset? _dragStartExtentCell;

  RenderTerminal get renderTerminal =>
      _viewportKey.currentContext!.findRenderObject() as RenderTerminal;

  TerminalController get controller => _controller;

  Terminal get terminal => widget.terminal;

  double get _minFontSize => widget.minFontSize;
  double get _maxFontSize => widget.maxFontSize;

  late double _fontSize;
  double? _scaleStartFontSize;
  double? _pendingScaledFontSize;
  bool _longPressActive = false;
  bool _tapDownInFocusHitbox = false;
  bool _suppressLongPress = false;
  bool _suppressPinch = false;
  bool _pinchInProgress = false;
  bool _pendingHitboxFocus = false;

  // Exposed for gesture handler to mark when a long-press is in progress.
  set longPressActive(bool value) => _longPressActive = value;
  bool get suppressLongPress => _suppressLongPress;

  @override
  void initState() {
    _focusNode = widget.focusNode ?? FocusNode();
    _controller = widget.controller ?? TerminalController();
    _scrollController = widget.scrollController ?? ScrollController();
    _shortcutManager = ShortcutManager(
      shortcuts: widget.shortcuts ?? defaultTerminalShortcuts,
    );
    _fontSize = widget.textStyle.fontSize.clamp(_minFontSize, _maxFontSize);
    _controller.addListener(_onSelectionChanged);
    _scrollController.addListener(_onScrollChanged);
    super.initState();
  }

  @override
  void didUpdateWidget(TerminalView oldWidget) {
    if (oldWidget.focusNode != widget.focusNode) {
      if (oldWidget.focusNode == null) {
        _focusNode.dispose();
      }
      _focusNode = widget.focusNode ?? FocusNode();
    }
    if (oldWidget.controller != widget.controller) {
      if (oldWidget.controller == null) {
        _controller.dispose();
      }
      _controller = widget.controller ?? TerminalController();
    }
    if (oldWidget.scrollController != widget.scrollController) {
      if (oldWidget.scrollController == null) {
        _scrollController.dispose();
      }
    _scrollController = widget.scrollController ?? ScrollController();
  }
  _shortcutManager.shortcuts = widget.shortcuts ?? defaultTerminalShortcuts;
  if (oldWidget.textStyle.fontSize != widget.textStyle.fontSize) {
    _fontSize = widget.textStyle.fontSize.clamp(_minFontSize, _maxFontSize);
  }
  super.didUpdateWidget(oldWidget);
}

@override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    if (widget.controller == null) {
      _controller.dispose();
    }
    if (widget.scrollController == null) {
      _scrollController.dispose();
    }
    _controller.removeListener(_onSelectionChanged);
    _scrollController.removeListener(_onScrollChanged);
    _shortcutManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = widget.textStyle.copyWith(fontSize: _fontSize);

    Widget child = Scrollable(
      key: _scrollableKey,
      controller: _scrollController,
      viewportBuilder: (context, offset) {
        return _TerminalView(
          key: _viewportKey,
          terminal: widget.terminal,
          controller: _controller,
          offset: offset,
          padding: MediaQuery.of(context).padding,
          autoResize: widget.autoResize,
          textStyle: textStyle,
          textScaler: widget.textScaler ?? MediaQuery.textScalerOf(context),
          theme: widget.theme,
          focusNode: _focusNode,
          cursorType: widget.cursorType,
          alwaysShowCursor: widget.alwaysShowCursor,
          onEditableRect: _onEditableRect,
          composingText: _composingText,
        );
      },
    );

    child = TerminalScrollGestureHandler(
      terminal: widget.terminal,
      simulateScroll: widget.simulateScroll,
      getCellOffset: (offset) => renderTerminal.getCellOffset(offset),
      getLineHeight: () => renderTerminal.lineHeight,
      child: child,
    );

    if (!widget.hardwareKeyboardOnly) {
      child = CustomTextEdit(
        key: _customTextEditKey,
        focusNode: _focusNode,
        autofocus: widget.autofocus,
        inputType: widget.keyboardType,
        keyboardAppearance: widget.keyboardAppearance,
        deleteDetection: widget.deleteDetection,
        onInsert: _onInsert,
        onDelete: () {
          _scrollToBottom();
          widget.terminal.keyInput(TerminalKey.backspace);
        },
        onComposing: _onComposing,
        onAction: (action) {
          _scrollToBottom();
          if (action == TextInputAction.done) {
            widget.terminal.keyInput(TerminalKey.enter);
          }
        },
        onKeyEvent: _handleKeyEvent,
        readOnly: widget.readOnly,
        child: child,
      );
    } else if (!widget.readOnly) {
      // Only listen for key input from a hardware keyboard.
      child = CustomKeyboardListener(
        child: child,
        focusNode: _focusNode,
        autofocus: widget.autofocus,
        onInsert: _onInsert,
        onComposing: _onComposing,
        onKeyEvent: _handleKeyEvent,
      );
    }

    child = TerminalActions(
      terminal: widget.terminal,
      controller: _controller,
      child: child,
    );


    child = KeyboardVisibilty(
      onKeyboardShow: _onKeyboardShow,
      child: child,
    );

    child = TerminalGestureHandler(
      terminalView: this,
      terminalController: _controller,
      onTapUp: _onTapUp,
      onTapDown: _onTapDown,
      onSecondaryTapDown:
          widget.onSecondaryTapDown != null ? _onSecondaryTapDown : null,
      onSecondaryTapUp:
          widget.onSecondaryTapUp != null ? _onSecondaryTapUp : null,
      readOnly: widget.readOnly,
      child: child,
    );

    child = MouseRegion(
      cursor: widget.mouseCursor,
      child: child,
    );

    if (widget.enablePinchZoom) {
      child = GestureDetector(
        behavior: HitTestBehavior.translucent,
        onScaleStart: _onScaleStart,
        onScaleUpdate: _onScaleUpdate,
        onScaleEnd: _onScaleEnd,
        child: child,
      );
    }

    final handleWidgets = _selectionHandles();

    final container = Container(
      color: widget.theme.background.withOpacity(widget.backgroundOpacity),
      padding: widget.padding,
      child: child,
    );

    return Stack(
      fit: StackFit.passthrough,
      children: [
        container,
        ...handleWidgets,
      ],
    );
  }

  void requestKeyboard() {
    _customTextEditKey.currentState?.requestKeyboard();
  }

  void closeKeyboard() {
    _customTextEditKey.currentState?.closeKeyboard();
  }

  Rect get cursorRect {
    return renderTerminal.cursorOffset & renderTerminal.cellSize;
  }

  Rect get globalCursorRect {
    return renderTerminal.localToGlobal(renderTerminal.cursorOffset) &
        renderTerminal.cellSize;
  }

  void _onScaleStart(ScaleStartDetails details) {
    if (details.pointerCount < 2) return;
    _pinchInProgress = true;
    if (_tapDownInFocusHitbox) {
      _suppressPinch = true;
      return;
    }
    _suppressPinch = false;
    _scaleStartFontSize = _fontSize;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (_suppressPinch) return;
    if (_scaleStartFontSize == null || details.pointerCount < 2) return;
    final next = (_scaleStartFontSize! * details.scale)
        .clamp(_minFontSize, _maxFontSize);
    if (next != _fontSize) {
      setState(() {
        _fontSize = next;
      });
      _pendingScaledFontSize = next;
    }
  }

  void _onScaleEnd(ScaleEndDetails details) {
    _pinchInProgress = false;
    if (_suppressPinch) {
      _suppressPinch = false;
      return;
    }
    if (_pendingScaledFontSize != null) {
      widget.onFontSizeChange?.call(_pendingScaledFontSize!);
    }
    _scaleStartFontSize = null;
    _pendingScaledFontSize = null;
  }

  void _onTapUp(TapUpDetails details) {
    final offset = renderTerminal.getCellOffset(details.localPosition);
    widget.onTapUp?.call(details, offset);
    AppLogger().debug(
      'tapUp: global=${details.globalPosition} local=${details.localPosition} '
      'kind=${details.kind} cursorOffset=${renderTerminal.cursorOffset}',
      tag: 'TerminalView',
    );

    // For touch, request the keyboard on tap-up so long-press doesn't
    // immediately pull it up. Treat unknown kind as touch to keep mobile
    // taps focusing the terminal.
    final kind = details.kind;
    if (kind == null ||
        kind == PointerDeviceKind.touch ||
        kind == PointerDeviceKind.stylus) {
      // Only focus if the tap was (or ended) in the focus hitbox around the cursor,
      // and we did not treat it as a long-press or pinch.
      final upInHitbox = _isWithinFocusHitbox(details.globalPosition);
      final shouldFocus = (_tapDownInFocusHitbox || upInHitbox) &&
          !_longPressActive &&
          !_pinchInProgress;
      if (shouldFocus) {
        _requestKeyboard();
      }
      _tapDownInFocusHitbox = false;
      _suppressLongPress = false;
      _longPressActive = false;
      _pendingHitboxFocus = false;
    }
  }

  void _onTapDown(TapDownDetails details) {
    _longPressActive = false;
    final kind = details.kind;
    if (kind == PointerDeviceKind.touch ||
        kind == PointerDeviceKind.stylus ||
        kind == null) {
      _tapDownInFocusHitbox = _isWithinFocusHitbox(details.globalPosition);
      _suppressLongPress = false;
      _pendingHitboxFocus = _tapDownInFocusHitbox;
      if (_tapDownInFocusHitbox) {
        _requestKeyboard();
      }
    } else {
      _tapDownInFocusHitbox = false;
      _suppressLongPress = false;
      _pendingHitboxFocus = false;
    }
    AppLogger().debug(
      'tapDown: global=${details.globalPosition} local=${details.localPosition} '
      'kind=$kind cursorOffset=${renderTerminal.cursorOffset} '
      'tapInHitbox=$_tapDownInFocusHitbox suppressLongPress=$_suppressLongPress',
      tag: 'TerminalView',
    );

    final selection = _controller.selection;
    final tappedCell = renderTerminal.getCellOffset(details.localPosition);

    // Keep an existing selection if the tap occurs inside it; otherwise
    // clear and focus as usual so taps outside the selection behave the same.
    final tappedInsideSelection =
        selection != null && selection.contains(tappedCell);

    if (selection != null && tappedInsideSelection) {
      return;
    }

    if (selection != null) {
      _controller.clearSelection();
      return;
    }

    // On touch, defer keyboard focus until we know it's a tap (not long-press).
    if (kind == PointerDeviceKind.touch ||
        kind == PointerDeviceKind.stylus ||
        kind == null) {
      return;
    }

    _requestKeyboard();
  }

  void _onLongPressUp(LongPressEndDetails details) {
    if (_suppressLongPress) return;
    final offset = renderTerminal.getCellOffset(details.localPosition);
    widget.onSecondaryTapDown?.call(
      TapDownDetails(
        globalPosition: details.globalPosition,
        localPosition: details.localPosition,
      ),
      offset,
    );
    widget.onSecondaryTapUp?.call(
      TapUpDetails(
        globalPosition: details.globalPosition,
        localPosition: details.localPosition,
        kind: PointerDeviceKind.touch,
      ),
      offset,
    );
    _longPressActive = false;
  }

  bool _isWithinFocusHitbox(Offset globalPosition) {
    final localPosition = renderTerminal.globalToLocal(globalPosition);
    final cursorRect = renderTerminal.cursorOffset & renderTerminal.cellSize;
    final cellHeight = renderTerminal.cellSize.height;
    final top = cursorRect.top - cellHeight < 0
        ? 0.0
        : cursorRect.top - cellHeight;
    final height = cellHeight * 3;
    final hitbox = Rect.fromLTWH(
      0,
      top,
      renderTerminal.size.width,
      height,
    );
    AppLogger().debug(
      'focus hitbox: cursorRect=$cursorRect hitbox=$hitbox '
      'localTap=$localPosition globalTap=$globalPosition '
      'tapDownHitbox=$_tapDownInFocusHitbox suppressLongPress=$_suppressLongPress',
      tag: 'TerminalView',
    );
    return hitbox.contains(localPosition);
  }

  void _requestKeyboard() {
    _focusNode.canRequestFocus = true;
    _focusNode.requestFocus();
    if (!widget.hardwareKeyboardOnly) {
      _customTextEditKey.currentState?.requestKeyboard();
    }
  }

  void _onSecondaryTapDown(TapDownDetails details) {
    final offset = renderTerminal.getCellOffset(details.localPosition);
    widget.onSecondaryTapDown?.call(details, offset);
  }

  void _onSecondaryTapUp(TapUpDetails details) {
    final offset = renderTerminal.getCellOffset(details.localPosition);
    widget.onSecondaryTapUp?.call(details, offset);
  }

  bool get hasInputConnection {
    return _customTextEditKey.currentState?.hasInputConnection == true;
  }

  void _onInsert(String text) {
    final key = charToTerminalKey(text.trim());

    // On mobile platforms there is no guarantee that virtual keyboard will
    // generate hardware key events. So we need first try to send the key
    // as a hardware key event. If it fails, then we send it as a text input.
    final consumed = key == null ? false : widget.terminal.keyInput(key);

    if (!consumed) {
      widget.terminal.textInput(text);
    }

    _scrollToBottom();
  }

  void _onComposing(String? text) {
    setState(() => _composingText = text);
  }

  KeyEventResult _handleKeyEvent(FocusNode focusNode, KeyEvent event) {
    final resultOverride = widget.onKeyEvent?.call(focusNode, event);
    if (resultOverride != null && resultOverride != KeyEventResult.ignored) {
      return resultOverride;
    }

    // ignore: invalid_use_of_protected_member
    final shortcutResult = _shortcutManager.handleKeypress(
      focusNode.context!,
      event,
    );

    if (shortcutResult != KeyEventResult.ignored) {
      return shortcutResult;
    }

    if (event is KeyUpEvent) {
      return KeyEventResult.ignored;
    }

    final key = keyToTerminalKey(event.logicalKey);

    if (key == null) {
      return KeyEventResult.ignored;
    }

    final handled = widget.terminal.keyInput(
      key,
      ctrl: HardwareKeyboard.instance.isControlPressed,
      alt: HardwareKeyboard.instance.isAltPressed,
      shift: HardwareKeyboard.instance.isShiftPressed,
    );

    if (handled) {
      _scrollToBottom();
    }

    return handled ? KeyEventResult.handled : KeyEventResult.ignored;
  }

  void _onKeyboardShow() {
    if (_focusNode.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    }
  }

  void _onEditableRect(Rect rect, Rect caretRect) {
    _customTextEditKey.currentState?.setEditableRect(rect, caretRect);
  }

  void _scrollToBottom() {
    final position = _scrollableKey.currentState?.position;
    if (position != null) {
      position.jumpTo(position.maxScrollExtent);
    }
  }

  void _onSelectionChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _onScrollChanged() {
    if (!mounted) return;
    if (_controller.selection != null) {
      setState(() {});
    }
  }

  bool get _isMobilePlatform =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  RenderTerminal? get _maybeRenderTerminal {
    final renderObject = _viewportKey.currentContext?.findRenderObject();
    if (renderObject is RenderTerminal) {
      return renderObject;
    }
    return null;
  }

  List<Widget> _selectionHandles() {
    if (!_isMobilePlatform) return const [];
    final selection = _controller.selection;
    final render = _maybeRenderTerminal;
    if (selection == null || render == null) {
      return const [];
    }
    final normalized = selection.normalized;
    final height = render.cellSize.height;

    Widget handle(Offset offset, bool isStart) {
      return Positioned(
        left: offset.dx - 16,
        top: offset.dy + height - 16,
        child: Listener(
          onPointerDown: (_) => _suspendScroll(true),
          onPointerUp: (_) => _suspendScroll(false),
          onPointerCancel: (_) => _suspendScroll(false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (details) => _onHandlePanStart(isStart, details),
            onPanUpdate: _onHandlePanUpdate,
            onPanEnd: _onHandlePanEnd,
            child: const SizedBox(
              width: 32,
              height: 32,
              child: Center(
                child: _SelectionBeacon(size: _selectionHandleSize),
              ),
            ),
          ),
        ),
      );
    }

    return [
      handle(render.getOffset(normalized.begin), true),
      handle(render.getOffset(normalized.end), false),
    ];
  }

  void _onHandlePanStart(bool draggingStartHandle, DragStartDetails details) {
    final selection = _controller.selection;
    final render = _maybeRenderTerminal;
    if (selection == null || render == null) return;
    final normalized = selection.normalized;
    _draggingSelectionHandle = true;
    _draggingStartHandle = draggingStartHandle;
    _dragStartBaseCell = normalized.begin;
    _dragStartExtentCell = normalized.end;
  }

  void _onHandlePanUpdate(DragUpdateDetails details) {
    if (!_draggingSelectionHandle) return;
    final render = _maybeRenderTerminal;
    if (render == null) return;

    Offset local = render.globalToLocal(details.globalPosition);
    final didScroll = _autoScrollIfNeeded(local);
    if (didScroll) {
      local = render.globalToLocal(details.globalPosition);
    }
    final cell = render.getCellOffset(local);

    final base = _draggingStartHandle ? cell : (_dragStartBaseCell ?? cell);
    final extent = _draggingStartHandle ? (_dragStartExtentCell ?? cell) : cell;

    _setSelectionFromCells(base, extent);
  }

  void _onHandlePanEnd(DragEndDetails details) {
    _draggingSelectionHandle = false;
    _dragStartBaseCell = null;
    _dragStartExtentCell = null;
    _suspendScroll(false);
  }

  void _suspendScroll(bool suspend) {
    _controller.setSuspendPointerInput(suspend);
  }

  void _setSelectionFromCells(CellOffset base, CellOffset extent) {
    final buffer = widget.terminal.buffer;
    final baseAnchor = buffer.createAnchorFromOffset(base);
    final extentAnchor = buffer.createAnchorFromOffset(extent);
    _controller.setSelection(baseAnchor, extentAnchor);
  }

  bool _autoScrollIfNeeded(Offset localPosition) {
    final scrollable = _scrollableKey.currentState?.position;
    final render = _maybeRenderTerminal;
    if (scrollable == null || render == null || !scrollable.hasPixels) {
      return false;
    }

    const edgeMargin = 40.0;
    double delta = 0;
    if (localPosition.dy < edgeMargin &&
        scrollable.pixels > scrollable.minScrollExtent) {
      delta = localPosition.dy - edgeMargin;
    } else if (localPosition.dy > render.size.height - edgeMargin &&
        scrollable.pixels < scrollable.maxScrollExtent) {
      delta = localPosition.dy - (render.size.height - edgeMargin);
    }

    if (delta == 0) {
      return false;
    }

    final target = (scrollable.pixels + delta)
        .clamp(scrollable.minScrollExtent, scrollable.maxScrollExtent);
    scrollable.jumpTo(target);
    return true;
  }
}

class _SelectionBeacon extends StatelessWidget {
  const _SelectionBeacon({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        border: Border.all(
          color: Colors.black.withOpacity(0.7),
          width: 1.5,
        ),
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
    );
  }
}

class _TerminalView extends LeafRenderObjectWidget {
  const _TerminalView({
    super.key,
    required this.terminal,
    required this.controller,
    required this.offset,
    required this.padding,
    required this.autoResize,
    required this.textStyle,
    required this.textScaler,
    required this.theme,
    required this.focusNode,
    required this.cursorType,
    required this.alwaysShowCursor,
    this.onEditableRect,
    this.composingText,
  });

  final Terminal terminal;

  final TerminalController controller;

  final ViewportOffset offset;

  final EdgeInsets padding;

  final bool autoResize;

  final TerminalStyle textStyle;

  final TextScaler textScaler;

  final TerminalTheme theme;

  final FocusNode focusNode;

  final TerminalCursorType cursorType;

  final bool alwaysShowCursor;

  final EditableRectCallback? onEditableRect;

  final String? composingText;

  @override
  RenderTerminal createRenderObject(BuildContext context) {
    return RenderTerminal(
      terminal: terminal,
      controller: controller,
      offset: offset,
      padding: padding,
      autoResize: autoResize,
      textStyle: textStyle,
      textScaler: textScaler,
      theme: theme,
      focusNode: focusNode,
      cursorType: cursorType,
      alwaysShowCursor: alwaysShowCursor,
      onEditableRect: onEditableRect,
      composingText: composingText,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderTerminal renderObject) {
    renderObject
      ..terminal = terminal
      ..controller = controller
      ..offset = offset
      ..padding = padding
      ..autoResize = autoResize
      ..textStyle = textStyle
      ..textScaler = textScaler
      ..theme = theme
      ..focusNode = focusNode
      ..cursorType = cursorType
      ..alwaysShowCursor = alwaysShowCursor
      ..onEditableRect = onEditableRect
      ..composingText = composingText;
  }
}
