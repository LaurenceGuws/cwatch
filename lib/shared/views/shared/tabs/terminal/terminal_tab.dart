import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';
import 'package:cwatch/services/ssh/terminal_session.dart';

import '../../../../../models/app_settings.dart';
import '../../../../../models/ssh_host.dart';
import '../../../../../services/ssh/remote_shell_service.dart';
import '../../../../../services/ssh/builtin/builtin_remote_shell_service.dart';
import '../../../../../services/settings/app_settings_controller.dart';
import '../../../../../shared/shortcuts/shortcut_actions.dart';
import '../../../../../shared/shortcuts/shortcut_resolver.dart';
import '../../../../../shared/shortcuts/shortcut_service.dart';
import '../../../../../shared/shortcuts/input_mode_resolver.dart';
import '../../../../../shared/gestures/gesture_activators.dart';
import '../../../../../shared/gestures/gesture_service.dart';
import '../../../../../shared/widgets/style_picker_dialog.dart';
import '../../../../theme/nerd_fonts.dart';
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
  final TerminalController _controller = TerminalController();
  final Terminal _terminal = Terminal(maxLines: 1000);
  final FocusNode _focusNode = FocusNode();
  bool get _isMobile =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
  VoidCallback? _focusListener;
  bool _suppressMobileFocus = false;
  TerminalSession? _pty;
  StreamSubscription<String>? _outputSub;
  bool _connecting = true;
  String? _error;
  bool _closing = false;
  int _sessionToken = 0;
  ShortcutSubscription? _shortcutSub;
  GestureSubscription? _gestureSub;
  late final VoidCallback _settingsListener;

  @override
  void initState() {
    super.initState();
    _attachTerminalHandlers();
    _focusListener = () {
      if (_isMobile && !_focusNode.hasFocus) {
        _focusNode.canRequestFocus = false;
      }
    };
    _focusNode.addListener(_focusListener!);
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
    _controller.dispose();
    _focusNode.removeListener(_focusListener ?? () {});
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
      final session = await widget.shellService.createTerminalSession(
        widget.host,
        options: _terminalSessionOptions(),
      );
      _pty = session;
      _applyTerminalSizeToSession();
      _outputSub?.cancel();
      _outputSub = const Utf8Decoder(
        allowMalformed: true,
      ).bind(session.output).listen(_handlePtyText);
      unawaited(
        session.exitCode.then((code) {
          if (!mounted || _closing || token != _sessionToken) return;
          if (code != 0) {
            _terminal.write('\r\nProcess exited with code $code\r\n');
            return;
          }
          _closing = true;
          widget.onExit?.call();
        }),
      );

      _terminal.textInput('clear');
      _terminal.keyInput(TerminalKey.enter);
      await _sendInitialDirectory();
      if (!mounted) {
        session.kill();
        return;
      }
      setState(() {
        _connecting = false;
      });
    } catch (error, stack) {
      _pty?.kill();
      debugPrint('Terminal session failed: $error\n$stack');
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
    _pty?.write(Uint8List.fromList(bytes));
  }

  void _onTerminalResize(
    int columns,
    int rows,
    int pixelWidth,
    int pixelHeight,
  ) {
    _pty?.resize(rows, columns);
  }

  void _applyTerminalSizeToSession() {
    final session = _pty;
    if (session == null) {
      return;
    }
    final rows = _terminal.viewHeight;
    final columns = _terminal.viewWidth;
    if (rows <= 0 || columns <= 0) {
      return;
    }
    session.resize(rows, columns);
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
    _pty?.kill();
    _pty = null;
    _outputSub?.cancel();
    _outputSub = null;
  }

  void _updateTabOptions() {
    final options = [
      TabChipOption(
        label: 'Restart terminal',
        icon: Icons.refresh,
        onSelected: _startSession,
      ),
      TabChipOption(
        label: 'Theme',
        icon: Icons.palette,
        onSelected: () => _showThemeDialog(context),
      ),
    ];
    final controller = widget.optionsController;
    if (controller is CompositeTabOptionsController) {
      controller.updateBase(options);
    } else {
      controller?.update(options);
    }
  }

  Future<void> _showThemeDialog(BuildContext context) async {
    await reloadUserTerminalThemes();
    if (!context.mounted) {
      return;
    }
    final brightness = Theme.of(context).colorScheme.brightness;
    final settings = widget.settingsController.settings;
    final savedTheme = brightness == Brightness.dark
        ? settings.terminalThemeDark
        : settings.terminalThemeLight;
    final labels = terminalThemeLabelCatalog();
    final initialKey = labels.containsKey(savedTheme)
        ? savedTheme
        : 'xterm-default';
    final options = labels.entries
        .map((entry) => StyleOption(key: entry.key, label: entry.value))
        .toList();

    final chosen = await showStylePickerDialog(
      context: context,
      title: 'Select terminal theme',
      options: options,
      selectedKey: initialKey,
      onPreview: (key) =>
          unawaited(_setTerminalThemeForBrightness(brightness, key)),
    );

    if (chosen == null) {
      await _setTerminalThemeForBrightness(brightness, savedTheme);
      return;
    }
    await _setTerminalThemeForBrightness(brightness, chosen);
  }

  Future<void> _setTerminalThemeForBrightness(
    Brightness brightness,
    String themeKey,
  ) {
    return widget.settingsController.update((current) {
      if (brightness == Brightness.dark) {
        if (current.terminalThemeDark == themeKey) return current;
        return current.copyWith(terminalThemeDark: themeKey);
      }
      if (current.terminalThemeLight == themeKey) return current;
      return current.copyWith(terminalThemeLight: themeKey);
    });
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
    await Clipboard.setData(ClipboardData(text: text));
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text;
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
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Failed to start terminal',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(_error ?? 'Unknown error', textAlign: TextAlign.center),
          const SizedBox(height: 12),
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
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
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
            return SizedBox(
              width: double.infinity,
              child: Actions(
                actions: {
                  _OpenScrollbackIntent: CallbackAction<_OpenScrollbackIntent>(
                    onInvoke: (intent) {
                      _openScrollbackInEditor();
                      return null;
                    },
                  ),
                },
                child: GestureDetector(
                  onLongPressStart: inputMode.enableGestures
                      ? (details) => _handleLongPress(details.globalPosition)
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

  void _enableMobileFocus() {
    if (!_isMobile || _suppressMobileFocus) return;
    _focusNode.canRequestFocus = true;
    _focusNode.requestFocus();
  }

  void _beginMobileGestureBlock() {
    if (!_isMobile) return;
    _suppressMobileFocus = true;
    _focusNode.unfocus();
    _focusNode.canRequestFocus = false;
  }

  void _endMobileGestureBlock() {
    if (!_isMobile) return;
    _suppressMobileFocus = false;
    _focusNode.canRequestFocus = true;
  }
}

class _OpenScrollbackIntent extends Intent {
  const _OpenScrollbackIntent();
}

enum _TerminalMenuAction { copy, paste, selectAll, openScrollback, clear }
