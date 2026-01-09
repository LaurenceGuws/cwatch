import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';

import 'package:cwatch/app/adapters/terminal_ui_adapter.dart';
import 'package:cwatch/app/controllers/terminal_session_controller.dart';
import 'package:cwatch/ui/bindings/terminal_tab_binding.dart';

import '../../../../../models/app_settings.dart';
import '../../../../../models/ssh_host.dart';
import '../../../../../services/ssh/remote_shell_service.dart';
import '../../../../../services/ssh/builtin/builtin_remote_shell_service.dart';
import '../../../../../services/settings/app_settings_controller.dart';
import '../../../../../services/logging/app_logger.dart';
import '../../../../../shared/shortcuts/shortcut_actions.dart';
import '../../../../../shared/shortcuts/shortcut_resolver.dart';
import '../../../../../shared/shortcuts/shortcut_service.dart';
import '../../../../../shared/shortcuts/input_mode_resolver.dart';
import '../../../../../shared/gestures/gesture_activators.dart';
import '../../../../../shared/gestures/gesture_service.dart';
import '../../../../../shared/theme/app_theme.dart';
import '../../../../../shared/widgets/mobile_focus_manager.dart';
import 'package:cwatch/modules/settings/ui/settings/terminal_settings_controls.dart';
import '../../../../theme/nerd_fonts.dart';
import '../settings/floating_settings_window.dart';
import '../tab_chip.dart';
import 'terminal_theme_presets.dart';

/// Terminal tab that spawns an SSH session via a PTY.
class TerminalTab extends StatefulWidget {
  const TerminalTab({
    super.key,
    required this.host,
    this.initialDirectory,
    required this.shellService,
    required this.settingsController,
    this.onOpenEditorTab,
    this.onExit,
    this.optionsController,
  });

  final SshHost host;
  final String? initialDirectory;
  final RemoteShellService shellService;
  final AppSettingsController settingsController;
  final Future<void> Function(String path, String content)? onOpenEditorTab;
  final VoidCallback? onExit;
  final TabOptionsController? optionsController;

  @override
  State<TerminalTab> createState() => _TerminalTabState();
}

class _TerminalTabState extends State<TerminalTab> {
  final TerminalTabBinding _binding = const TerminalTabBinding();
  final TerminalController _controller = TerminalController();
  final Terminal _terminal = Terminal(maxLines: 1000);
  final FocusNode _focusNode = FocusNode();
  late TerminalSessionController _sessionController;
  late TerminalUiAdapter _uiAdapter;
  bool get _isMobile =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
  late final MobileFocusManager _mobileFocus;
  bool _connecting = true;
  String? _error;
  bool _closing = false;
  int _sessionToken = 0;
  ShortcutSubscription? _shortcutSub;
  GestureSubscription? _gestureSub;
  late final VoidCallback _settingsListener;
  bool _showSettings = false;

  @override
  void initState() {
    super.initState();
    _sessionController = _binding.createSessionController(
      host: widget.host,
      shellService: widget.shellService,
    );
    _uiAdapter = _binding.createUiAdapter(context: context);
    _attachTerminalHandlers();
    _mobileFocus = MobileFocusManager(
      focusNode: _focusNode,
      isMobile: _isMobile,
    );
    _mobileFocus.attach();
    _settingsListener = _handleSettingsChanged;
    widget.settingsController.addListener(_settingsListener);
    _configureInputMode(widget.settingsController.settings);
    unawaited(reloadUserTerminalThemes());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isMobile) {
        _focusNode.requestFocus();
      }
      _startSession();
    });
  }

  @override
  void dispose() {
    _closing = true;
    _resetSession();
    _sessionController.dispose();
    _controller.dispose();
    _mobileFocus.detach();
    _focusNode.dispose();
    _shortcutSub?.dispose();
    _gestureSub?.dispose();
    widget.settingsController.removeListener(_settingsListener);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant TerminalTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.optionsController != widget.optionsController) {
      _updateTabOptions();
    }
  }

  Future<void> _startSession() async {
    _attachTerminalHandlers();
    _sessionToken += 1;
    final token = _sessionToken;
    _closing = false;
    _resetSession();
    setState(() {
      _connecting = true;
      _error = null;
    });
    _updateTabOptions();

    _terminal.buffer.clear();
    _terminal.buffer.setCursor(0, 0);

    try {
      await _sessionController.start(
        options: _terminalSessionOptions(),
        onOutput: _handlePtyText,
        onExit: (code) {
          if (!mounted || _closing || token != _sessionToken) return;
          if (code != 0) {
            _terminal.write('\r\nProcess exited with code $code\r\n');
            return;
          }
          _closing = true;
          widget.onExit?.call();
        },
      );
      _applyTerminalSizeToSession();

      _terminal.textInput('clear');
      _terminal.keyInput(TerminalKey.enter);
      await _sendInitialDirectory();
      if (!mounted) {
        _sessionController.reset();
        return;
      }
      setState(() {
        _connecting = false;
      });
    } catch (error, stack) {
      _sessionController.reset();
      AppLogger().warn(
        'Terminal session failed',
        tag: 'Terminal',
        error: error,
        stackTrace: stack,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _error = _friendlyError(error);
        _connecting = false;
      });
    }
  }

  TerminalSessionOptions _terminalSessionOptions() {
    final columns = _terminal.viewWidth > 0 ? _terminal.viewWidth : 80;
    final rows = _terminal.viewHeight > 0 ? _terminal.viewHeight : 25;
    return TerminalSessionOptions(columns: columns, rows: rows);
  }

  Future<void> _sendInitialDirectory() async {
    final target = widget.initialDirectory?.trim();
    if (target == null || target.isEmpty) {
      return;
    }
    final escaped = _shellEscape(target);
    _terminal.textInput('cd $escaped\n');
    await Future.delayed(const Duration(milliseconds: 100));
  }

  void _onTerminalOutput(String value) {
    final bytes = utf8.encode(value);
    if (bytes.isEmpty) {
      return;
    }
    _sessionController.write(Uint8List.fromList(bytes));
  }

  void _onTerminalResize(
    int columns,
    int rows,
    int pixelWidth,
    int pixelHeight,
  ) {
    _sessionController.resize(rows, columns);
  }

  void _applyTerminalSizeToSession() {
    final rows = _terminal.viewHeight;
    final columns = _terminal.viewWidth;
    if (rows <= 0 || columns <= 0) {
      return;
    }
    _sessionController.resize(rows, columns);
  }

  void _attachTerminalHandlers() {
    _terminal.onOutput = _onTerminalOutput;
    _terminal.onResize = _onTerminalResize;
  }

  void _handlePtyText(String text) {
    if (text.isEmpty) {
      return;
    }
    _terminal.write(text);
  }

  void _resetSession() {
    _sessionController.reset();
  }

  void _updateTabOptions() {
    final options = [
      TabChipOption(
        label: 'Restart terminal',
        icon: Icons.refresh,
        onSelected: _startSession,
      ),
      TabChipOption(
        label: _showSettings ? 'Hide settings' : 'Settings',
        icon: Icons.settings,
        onSelected: _toggleSettings,
      ),
    ];
    final controller = widget.optionsController;
    if (controller is CompositeTabOptionsController) {
      controller.updateBase(options);
    } else {
      controller?.update(options);
    }
  }

  void _toggleSettings() {
    setState(() {
      _showSettings = !_showSettings;
    });
    _updateTabOptions();
  }

  String _shellEscape(String input) {
    final escaped = input.replaceAll("'", r"'\''");
    return "'$escaped'";
  }

  String _friendlyError(Object error) {
    if (error is BuiltInSshKeyLockedException) {
      final keyLabel = (error.keyLabel ?? error.keyId).trim();
      final label = keyLabel.isNotEmpty ? keyLabel : error.keyId;
      return 'Unlock SSH key "$label" to start a terminal.';
    }
    return error.toString();
  }

  Future<void> _showContextMenu(Offset globalPosition) async {
    final overlay = Overlay.of(context);
    final renderBox = overlay.context.findRenderObject() as RenderBox?;
    if (renderBox == null) {
      return;
    }
    final selection = _controller.selection;
    final action = await showMenu<_TerminalMenuAction>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(globalPosition.dx, globalPosition.dy, 0, 0),
        Offset.zero & renderBox.size,
      ),
      items: [
        PopupMenuItem(
          value: _TerminalMenuAction.copy,
          enabled: selection != null,
          child: const Text('Copy selection'),
        ),
        const PopupMenuItem(
          value: _TerminalMenuAction.paste,
          child: Text('Paste'),
        ),
        const PopupMenuItem(
          value: _TerminalMenuAction.selectAll,
          child: Text('Select all'),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: _TerminalMenuAction.openScrollback,
          enabled: _terminal.buffer.lines.length > 0,
          child: const Text('Open scrollback in editor'),
        ),
        const PopupMenuItem(
          value: _TerminalMenuAction.clear,
          child: Text('Clear screen'),
        ),
      ],
    );

    switch (action) {
      case _TerminalMenuAction.copy:
        await _copySelectionToClipboard();
        break;
      case _TerminalMenuAction.paste:
        await _pasteFromClipboard();
        break;
      case _TerminalMenuAction.selectAll:
        _selectAll();
        break;
      case _TerminalMenuAction.openScrollback:
        await _openScrollbackInEditor();
        break;
      case _TerminalMenuAction.clear:
        _sendClearCommand();
        break;
      case null:
        break;
    }
  }

  Future<void> _copySelectionToClipboard() async {
    final selection = _controller.selection;
    if (selection == null) {
      return;
    }
    final text = _terminal.buffer.getText(selection);
    if (text.isEmpty) {
      return;
    }
    await _uiAdapter.copyToClipboard(text);
  }

  Future<void> _pasteFromClipboard() async {
    final text = await _uiAdapter.readClipboardText();
    if (text == null || text.isEmpty) {
      return;
    }
    _terminal.textInput(text);
  }

  void _selectAll() {
    final buffer = _terminal.buffer;
    final lineCount = buffer.lines.length;
    if (lineCount == 0) {
      return;
    }
    final endLine = lineCount - 1;
    final endCol = buffer.viewWidth > 0 ? buffer.viewWidth - 1 : 0;
    final base = buffer.createAnchor(0, 0);
    final extent = buffer.createAnchor(endCol, endLine);
    _controller.setSelection(base, extent);
  }

  void _sendClearCommand() {
    _controller.clearSelection();
    _terminal.textInput('clear');
    _terminal.keyInput(TerminalKey.enter);
  }

  Future<void> _openScrollbackInEditor() async {
    final openEditor = widget.onOpenEditorTab;
    if (openEditor == null) {
      return;
    }
    final content = _terminal.buffer.getText();
    if (content.trim().isEmpty) {
      return;
    }
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final label =
        '/tmp/${widget.host.name}-scrollback-$timestamp.log'; // display label
    await openEditor(label, content);
  }

  Widget _buildError(BuildContext context) {
    final spacing = context.appTheme.spacing;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Failed to start terminal',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SizedBox(height: spacing.md),
          Text(_error ?? 'Unknown error', textAlign: TextAlign.center),
          SizedBox(height: spacing.lg),
          FilledButton(onPressed: _startSession, child: const Text('Retry')),
        ],
      ),
    );
  }

  static const double _minTerminalHeight = 120;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.settingsController,
      builder: (context, _) {
        if (_connecting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (_error != null) {
          return _buildError(context);
        }
        final settings = widget.settingsController.settings;
        final inputMode = resolveInputMode(
          settings.inputModePreference,
          defaultTargetPlatform,
        );
        return LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxHeight < _minTerminalHeight) {
              final spacing = context.appTheme.spacing;
              return Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: spacing.xl),
                  child: Text(
                    'Terminal needs at least ${_minTerminalHeight.toInt()} px '
                    'of vertical space. Increase the window height to use '
                    'this tab.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              );
            }
            return Stack(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: Actions(
                    actions: {
                      _OpenScrollbackIntent:
                          CallbackAction<_OpenScrollbackIntent>(
                            onInvoke: (intent) {
                              _openScrollbackInEditor();
                              return null;
                            },
                          ),
                    },
                    child: GestureDetector(
                      onLongPressStart: inputMode.enableGestures
                          ? (details) =>
                                _handleLongPress(details.globalPosition)
                          : null,
                      onTap: _isMobile ? _enableMobileFocus : null,
                      onScaleStart: _isMobile
                          ? (_) => _beginMobileGestureBlock()
                          : null,
                      onScaleEnd: _isMobile
                          ? (_) => _endMobileGestureBlock()
                          : null,
                      child: TerminalView(
                        _terminal,
                        controller: _controller,
                        focusNode: _focusNode,
                        autofocus: !_isMobile,
                        hardwareKeyboardOnly: !kIsWeb && !_isMobile,
                        backgroundOpacity: 1,
                        onKeyEvent: _handleTerminalKeyEvent,
                        padding: EdgeInsets.symmetric(
                          horizontal: settings.terminalPaddingX
                              .clamp(0, 48)
                              .toDouble(),
                          vertical: settings.terminalPaddingY
                              .clamp(0, 48)
                              .toDouble(),
                        ),
                        alwaysShowCursor: true,
                        deleteDetection:
                            defaultTargetPlatform == TargetPlatform.android ||
                            defaultTargetPlatform == TargetPlatform.iOS,
                        textStyle: _textStyle(settings),
                        theme: _terminalTheme(context, settings),
                        minFontSize: 8,
                        maxFontSize: 32,
                        enablePinchZoom: inputMode.enableGestures,
                        onFontSizeChange: _handlePinchZoom,
                        shortcuts: _terminalShortcuts(settings),
                        onSecondaryTapDown: (details, _) =>
                            _showContextMenu(details.globalPosition),
                      ),
                    ),
                  ),
                ),
                if (_showSettings)
                  FloatingSettingsWindow(
                    title: 'Terminal Settings',
                    onClose: _toggleSettings,
                    child: TerminalSettingsControls(
                      fontFamily: settings.terminalFontFamily,
                      fontSize: settings.terminalFontSize,
                      lineHeight: settings.terminalLineHeight,
                      paddingX: settings.terminalPaddingX,
                      paddingY: settings.terminalPaddingY,
                      darkTheme: settings.terminalThemeDark,
                      lightTheme: settings.terminalThemeLight,
                      onFontFamilyChanged: (value) => widget.settingsController
                          .update((s) => s.copyWith(terminalFontFamily: value)),
                      onFontSizeChanged: (value) => widget.settingsController
                          .update((s) => s.copyWith(terminalFontSize: value)),
                      onLineHeightChanged: (value) => widget.settingsController
                          .update((s) => s.copyWith(terminalLineHeight: value)),
                      onPaddingXChanged: (value) => widget.settingsController
                          .update((s) => s.copyWith(terminalPaddingX: value)),
                      onPaddingYChanged: (value) => widget.settingsController
                          .update((s) => s.copyWith(terminalPaddingY: value)),
                      onDarkThemeChanged: (value) => widget.settingsController
                          .update((s) => s.copyWith(terminalThemeDark: value)),
                      onLightThemeChanged: (value) => widget.settingsController
                          .update((s) => s.copyWith(terminalThemeLight: value)),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  TerminalStyle _textStyle(AppSettings settings) {
    return TerminalStyle(
      fontFamily: NerdFonts.effectiveTerminalFamily(
        settings.terminalFontFamily,
      ),
      fontFamilyFallback: NerdFonts.terminalFallbackFamilies,
      fontSize: settings.terminalFontSize.clamp(8, 32),
      height: settings.terminalLineHeight.clamp(0.8, 2.0),
    );
  }

  TerminalTheme _terminalTheme(BuildContext context, AppSettings settings) {
    final brightness = Theme.of(context).colorScheme.brightness;
    final key = brightness == Brightness.dark
        ? settings.terminalThemeDark
        : settings.terminalThemeLight;
    return terminalThemeForKey(key);
  }

  Map<ShortcutActivator, Intent> _terminalShortcuts(AppSettings settings) {
    final inputMode = resolveInputMode(
      settings.inputModePreference,
      defaultTargetPlatform,
    );
    if (!inputMode.enableShortcuts) {
      return const {};
    }
    final resolver = ShortcutResolver(settings);
    final map = <ShortcutActivator, Intent>{};

    void add(String id, Intent intent) {
      final binding = resolver.bindingFor(id);
      if (binding == null) return;
      map[binding.toActivator()] = intent;
    }

    add(ShortcutActions.terminalCopy, CopySelectionTextIntent.copy);
    add(
      ShortcutActions.terminalPaste,
      const PasteTextIntent(SelectionChangedCause.keyboard),
    );
    add(
      ShortcutActions.terminalSelectAll,
      const SelectAllTextIntent(SelectionChangedCause.keyboard),
    );
    add(ShortcutActions.terminalOpenScrollback, const _OpenScrollbackIntent());

    return map;
  }

  KeyEventResult _handleTerminalKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    return ShortcutService.instance.shouldSuppressEvent(event)
        ? KeyEventResult.handled
        : KeyEventResult.ignored;
  }

  Future<void> _changeTerminalFont(double delta) async {
    final next = (widget.settingsController.settings.terminalFontSize + delta)
        .clamp(8, 32)
        .toDouble();
    await _setTerminalFontSize(next);
  }

  Future<void> _setTerminalFontSize(double value) async {
    await widget.settingsController.update((current) {
      final next = value.clamp(8, 32).toDouble();
      if (next == current.terminalFontSize) return current;
      return current.copyWith(terminalFontSize: next);
    });
  }

  void _registerShortcuts() {
    _shortcutSub = ShortcutService.instance.registerScope(
      id: 'terminal',
      handlers: {
        ShortcutActions.terminalZoomIn: () => _changeTerminalFont(1),
        ShortcutActions.terminalZoomOut: () => _changeTerminalFont(-1),
      },
      focusNode: _focusNode,
      priority: 5,
      consumeOnHandle: true,
    );
  }

  void _configureShortcuts(InputModeConfig inputMode) {
    if (!inputMode.enableShortcuts) {
      _shortcutSub?.dispose();
      _shortcutSub = null;
      return;
    }
    if (_shortcutSub != null) return;
    _registerShortcuts();
  }

  void _handleSettingsChanged() {
    _configureInputMode(widget.settingsController.settings);
  }

  void _configureInputMode(AppSettings settings) {
    final inputMode = resolveInputMode(
      settings.inputModePreference,
      defaultTargetPlatform,
    );
    _configureShortcuts(inputMode);
    _configureGestures(inputMode);
  }

  void _configureGestures(InputModeConfig inputMode) {
    if (!inputMode.enableGestures) {
      _gestureSub?.dispose();
      _gestureSub = null;
      return;
    }
    if (_gestureSub != null) return;
    _gestureSub = GestureService.instance.registerScope(
      id: 'terminal_gestures',
      handlers: {
        Gestures.terminalPinchZoom: (invocation) {
          final next = invocation.payloadAs<double>();
          if (next != null) {
            unawaited(_setTerminalFontSize(next));
          }
        },
        Gestures.terminalLongPressMenu: (invocation) {
          final offset = invocation.payloadAs<Offset>();
          if (offset != null) {
            _showContextMenu(offset);
          }
        },
      },
      focusNode: _focusNode,
      priority: 5,
    );
  }

  void _handlePinchZoom(double value) {
    final handled = GestureService.instance.handle(
      Gestures.terminalPinchZoom,
      payload: value,
    );
    if (!handled) {
      unawaited(_setTerminalFontSize(value));
    }
  }

  void _handleLongPress(Offset globalPosition) {
    // Treat long-press as a context tap (right-click equivalent) without toggling focus.
    final handled = GestureService.instance.handle(
      Gestures.terminalLongPressMenu,
      payload: globalPosition,
    );
    if (!handled) {
      _showContextMenu(globalPosition);
    }
  }

  void _enableMobileFocus() => _mobileFocus.enableFocus();

  void _beginMobileGestureBlock() => _mobileFocus.beginGestureBlock();

  void _endMobileGestureBlock() => _mobileFocus.endGestureBlock();
}

class _OpenScrollbackIntent extends Intent {
  const _OpenScrollbackIntent();
}

enum _TerminalMenuAction { copy, paste, selectAll, openScrollback, clear }
