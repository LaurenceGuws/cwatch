import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';
import 'package:cwatch/services/ssh/terminal_session.dart';

import 'package:cwatch/models/app_settings.dart';
import 'package:cwatch/models/ssh_host.dart';
import 'package:cwatch/services/ssh/remote_shell_service.dart';
import 'package:cwatch/services/settings/app_settings_controller.dart';
import 'package:cwatch/shared/shortcuts/shortcut_actions.dart';
import 'package:cwatch/shared/shortcuts/shortcut_resolver.dart';
import 'package:cwatch/shared/shortcuts/shortcut_service.dart';
import 'package:cwatch/shared/theme/nerd_fonts.dart';
import 'package:cwatch/shared/views/shared/tabs/tab_chip.dart';
import 'package:cwatch/shared/views/shared/tabs/terminal/terminal_theme_presets.dart';

/// Lightweight terminal view that runs a provided Docker command locally or via SSH.
class DockerCommandTerminal extends StatefulWidget {
  const DockerCommandTerminal({
    super.key,
    required this.command,
    required this.title,
    this.host,
    this.shellService,
    this.settingsController,
    this.showCopyButton = true,
    this.autofocus = true,
    this.onExit,
    this.optionsController,
  });

  final SshHost? host;
  final RemoteShellService? shellService;
  final String command;
  final String title;
  final AppSettingsController? settingsController;
  final bool showCopyButton;
  final bool autofocus;
  final VoidCallback? onExit;
  final TabOptionsController? optionsController;

  @override
  State<DockerCommandTerminal> createState() => _DockerCommandTerminalState();
}

class _DockerCommandTerminalState extends State<DockerCommandTerminal> {
  final TerminalController _controller = TerminalController();
  final Terminal _terminal = Terminal(maxLines: 1000);
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  ShortcutSubscription? _shortcutSub;
  TerminalSession? _pty;
  StreamSubscription<String>? _outputSub;
  bool _connecting = true;
  String? _error;
  final StringBuffer _outputBuffer = StringBuffer();
  int _sessionToken = 0;
  String? _lastSelectionSignature;
  double? _lastLoggedScroll;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_logSelectionChange);
    _scrollController.addListener(_logScrollChange);
    _registerShortcuts();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      _start();
    });
  }

  @override
  void dispose() {
    _pty?.kill();
    _outputSub?.cancel();
    _controller.removeListener(_logSelectionChange);
    _scrollController.removeListener(_logScrollChange);
    _scrollController.dispose();
    _controller.dispose();
    _shortcutSub?.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant DockerCommandTerminal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.command != widget.command || oldWidget.host != widget.host) {
      _start();
    }
    if (oldWidget.optionsController != widget.optionsController ||
        oldWidget.showCopyButton != widget.showCopyButton) {
      _updateTabOptions();
    }
  }

  Future<void> _start() async {
    _sessionToken += 1;
    final token = _sessionToken;
    setState(() {
      _connecting = true;
      _error = null;
      _outputBuffer.clear();
    });
    _terminal.onOutput = _onOutput;
    _terminal.onResize = _onResize;
    _terminal.buffer.clear();
    try {
      final session = widget.host != null && widget.shellService != null
          ? await widget.shellService!.createTerminalSession(
              widget.host!,
              options: _sessionOptions(),
            )
          : LocalPtySession(
              executable: 'bash',
              arguments: const ['-l'],
              cols: _sessionOptions().columns,
              rows: _sessionOptions().rows,
            );

      if (token != _sessionToken) {
        session.kill();
        return;
      }
      _pty = session;
      _outputSub?.cancel();
      _outputSub =
          const Utf8Decoder(allowMalformed: true).bind(session.output).listen(
                _handlePtyText,
              );
      unawaited(
        session.exitCode.then((_) {
          if (!mounted || token != _sessionToken) return;
          widget.onExit?.call();
        }),
      );

      // Send the command into the PTY after the session is ready.
      _terminal.textInput('${widget.command}\n');
      setState(() => _connecting = false);
      _updateTabOptions();
    } catch (error, stack) {
      debugPrint('DockerCommandTerminal failed: $error\n$stack');
      setState(() {
        _connecting = false;
        _error = error.toString();
      });
      _updateTabOptions();
    }
  }

  TerminalSessionOptions _sessionOptions() {
    final columns = _terminal.viewWidth > 0 ? _terminal.viewWidth : 80;
    final rows = _terminal.viewHeight > 0 ? _terminal.viewHeight : 25;
    if (columns <= 0 || rows <= 0) {
      return const TerminalSessionOptions(columns: 80, rows: 25);
    }
    return TerminalSessionOptions(columns: columns, rows: rows);
  }

  void _handlePtyText(String text) {
    if (text.isEmpty) return;
    _terminal.write(text);
    _outputBuffer.write(text);
    _logSelectionChange();
  }

  void _onOutput(String value) {
    final bytes = utf8.encode(value);
    if (bytes.isEmpty) return;
    _pty?.write(Uint8List.fromList(bytes));
    _outputBuffer.write(value);
    _logSelectionChange();
  }

  void _onResize(int columns, int rows, int pixelWidth, int pixelHeight) {
    if (columns <= 0 || rows <= 0) return;
    _pty?.resize(rows, columns);
  }

  Future<void> _copyOutput() async {
    final selection = _controller.selection;
    if (selection != null) {
      final selected = _terminal.buffer.getText(selection);
      final cleaned = _stripAnsi(selected);
      if (cleaned.trim().isEmpty) return;
      await Clipboard.setData(ClipboardData(text: cleaned));
    } else {
      if (_outputBuffer.isEmpty) return;
      final plain = _stripAnsi(_outputBuffer.toString());
      await Clipboard.setData(ClipboardData(text: plain));
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          selection != null
              ? 'Selection copied to clipboard'
              : 'Output copied to clipboard',
        ),
      ),
    );
    _logSelectionChange(force: true);
    _updateTabOptions();
  }

  String _stripAnsi(String input) {
    var output = input;
    // OSC sequences: ESC ] ... BEL or ESC \
    output = output.replaceAll(RegExp(r'\x1B\][\s\S]*?(?:\x07|\x1B\\)'), '');
    // CSI sequences
    output = output.replaceAll(RegExp(r'\x1B\[[0-?]*[ -/]*[@-~]'), '');
    // Single ESC codes
    output = output.replaceAll(RegExp(r'\x1B[@-Z\\-_]'), '');
    return output;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.settingsController != null) {
      return AnimatedBuilder(
        animation: widget.settingsController!,
        builder: (context, _) =>
            _buildContent(context, widget.settingsController!.settings),
      );
    }
    return _buildContent(context, null);
  }

  Widget _buildContent(BuildContext context, AppSettings? settings) {
    if (_error != null) {
      return Center(child: Text(_error!));
    }
    if (_connecting) {
      return const Center(child: CircularProgressIndicator());
    }
    final resolvedSettings = settings ?? widget.settingsController?.settings;
    return Actions(
      actions: {
        _ScrollByIntent: CallbackAction<_ScrollByIntent>(
          onInvoke: (intent) {
            _scrollBy(intent.offset);
            return null;
          },
        ),
        _ScrollToExtentIntent: CallbackAction<_ScrollToExtentIntent>(
          onInvoke: (intent) {
            _scrollToExtent(intent.up);
            return null;
          },
        ),
        _CopyTerminalIntent: CallbackAction<_CopyTerminalIntent>(
          onInvoke: (intent) {
            _copyOutput();
            return null;
          },
        ),
      },
      child: TerminalView(
        _terminal,
        controller: _controller,
        scrollController: _scrollController,
        focusNode: _focusNode,
        shortcuts: _shortcutBindings(resolvedSettings),
        autofocus: widget.autofocus,
        alwaysShowCursor: true,
        padding: EdgeInsets.symmetric(
          horizontal:
              (resolvedSettings?.terminalPaddingX ?? 8).clamp(0, 48).toDouble(),
          vertical:
              (resolvedSettings?.terminalPaddingY ?? 10).clamp(0, 48).toDouble(),
        ),
        textStyle: _textStyle(resolvedSettings),
        theme: _terminalTheme(context, resolvedSettings),
        onSecondaryTapDown: (details, _) =>
            _showContextMenu(details.globalPosition),
      ),
    );
  }

  Map<ShortcutActivator, Intent> _shortcutBindings(AppSettings? settings) {
    final resolver = ShortcutResolver(settings);
    final map = <ShortcutActivator, Intent>{};

    void add(String actionId, Intent intent) {
      final binding = resolver.bindingFor(actionId);
      if (binding == null) return;
      map[binding.toActivator()] = intent;
    }

    add(
      ShortcutActions.terminalScrollLineUp,
      const _ScrollByIntent(-160),
    );
    add(
      ShortcutActions.terminalScrollLineDown,
      const _ScrollByIntent(160),
    );
    add(
      ShortcutActions.terminalScrollPageUp,
      const _ScrollByIntent(-480),
    );
    add(
      ShortcutActions.terminalScrollPageDown,
      const _ScrollByIntent(480),
    );
    add(
      ShortcutActions.terminalScrollToTop,
      const _ScrollToExtentIntent(up: true),
    );
    add(
      ShortcutActions.terminalScrollToBottom,
      const _ScrollToExtentIntent(up: false),
    );

    return map;
  }

  Future<void> _changeTerminalFont(double delta) async {
    final controller = widget.settingsController;
    if (controller == null) {
      return;
    }
    await controller.update((current) {
      final next = (current.terminalFontSize + delta).clamp(8, 32).toDouble();
      return current.copyWith(terminalFontSize: next);
    });
  }

  void _registerShortcuts() {
    _shortcutSub = ShortcutService.instance.registerScope(
      id: 'docker_terminal',
      handlers: {
        ShortcutActions.terminalZoomIn: () => _changeTerminalFont(1),
        ShortcutActions.terminalZoomOut: () => _changeTerminalFont(-1),
      },
      focusNode: _focusNode,
      priority: 5,
      consumeOnHandle: true,
    );
  }

  Future<void> _showContextMenu(Offset globalPosition) async {
    final overlay = Overlay.of(context);
    final renderBox = overlay.context.findRenderObject() as RenderBox?;
    if (renderBox == null) {
      return;
    }
    final selection = _controller.selection;
    final hasSelection =
        selection != null && _safeSelectionText(selection).isNotEmpty;
    final action = await showMenu<_TerminalMenuAction>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(globalPosition.dx, globalPosition.dy, 0, 0),
        Offset.zero & renderBox.size,
      ),
      items: [
        PopupMenuItem(
          value: _TerminalMenuAction.copySelection,
          enabled: hasSelection,
          child: const Text('Copy selection'),
        ),
        PopupMenuItem(
          value: _TerminalMenuAction.copyAll,
          enabled: _outputBuffer.isNotEmpty,
          child: const Text('Copy all output'),
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
        const PopupMenuItem(
          value: _TerminalMenuAction.clear,
          child: Text('Clear screen'),
        ),
      ],
    );

    switch (action) {
      case _TerminalMenuAction.copySelection:
        await _copySelectionOnly();
        break;
      case _TerminalMenuAction.copyAll:
        await _copyAllOutput();
        break;
      case _TerminalMenuAction.paste:
        await _pasteFromClipboard();
        break;
      case _TerminalMenuAction.selectAll:
        _selectAll();
        break;
      case _TerminalMenuAction.clear:
        _sendClearCommand();
        break;
      case null:
        break;
    }
  }

  Future<void> _copySelectionOnly() async {
    final selection = _controller.selection;
    if (selection == null) return;
    final text = _safeSelectionText(selection);
    final cleaned = _stripAnsi(text);
    if (cleaned.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: cleaned));
  }

  Future<void> _copyAllOutput() async {
    if (_outputBuffer.isEmpty) return;
    final plain = _stripAnsi(_outputBuffer.toString());
    if (plain.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: plain));
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

  void _scrollBy(double offset) {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final target = (position.pixels + offset).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    position.jumpTo(target);
  }

  void _scrollToExtent(bool up) {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    position.jumpTo(up ? position.minScrollExtent : position.maxScrollExtent);
  }

  void _logScrollChange() {
    if (!_scrollController.hasClients) return;
    final current = _scrollController.position.pixels;
    // Avoid log spam for tiny deltas.
    if (_lastLoggedScroll != null && (current - _lastLoggedScroll!).abs() < 4) {
      return;
    }
    _lastLoggedScroll = current;
  }

  void _logSelectionChange({bool force = false}) {
    final selection = _controller.selection;
    if (selection == null) {
      _lastSelectionSignature = null;
      _updateTabOptions();
      return;
    }
    final text = _safeSelectionText(selection);
    final signature = '${selection.begin}-${selection.end}|${text.hashCode}';
    if (!force && signature == _lastSelectionSignature) {
      return;
    }
    _lastSelectionSignature = signature;
    _updateTabOptions();
  }

  TerminalStyle _textStyle(AppSettings? settings) {
    final fontSize = (settings?.terminalFontSize ?? 14).clamp(8, 32).toDouble();
    final lineHeight = (settings?.terminalLineHeight ?? 1.4)
        .clamp(0.8, 2.0)
        .toDouble();
    return TerminalStyle(
      fontFamily:
          NerdFonts.effectiveTerminalFamily(settings?.terminalFontFamily),
      fontFamilyFallback: NerdFonts.terminalFallbackFamilies,
      fontSize: fontSize,
      height: lineHeight,
    );
  }

  TerminalTheme _terminalTheme(BuildContext context, AppSettings? settings) {
    final brightness = Theme.of(context).colorScheme.brightness;
    final key = brightness == Brightness.dark
        ? settings?.terminalThemeDark ?? 'dracula'
        : settings?.terminalThemeLight ?? 'solarized-light';
    return terminalThemeForKey(key);
  }

  String _safeSelectionText(BufferRange selection) {
    try {
      return _terminal.buffer.getText(selection);
    } catch (error) {
      return '';
    }
  }

  bool get _hasCopyableText =>
      _controller.selection != null || _outputBuffer.isNotEmpty;

  void _updateTabOptions() {
    final controller = widget.optionsController;
    if (controller == null) {
      return;
    }
    final options = <TabChipOption>[];
    if (widget.showCopyButton) {
      options.add(
        TabChipOption(
          label: 'Copy output',
          icon: Icons.copy,
          enabled: _hasCopyableText,
          onSelected: _copyOutput,
        ),
      );
    }
    if (controller is CompositeTabOptionsController) {
      controller.updateBase(options);
      return;
    }
    controller.update(options);
  }
}

class _ScrollByIntent extends Intent {
  const _ScrollByIntent(this.offset);
  final double offset;
}

class _ScrollToExtentIntent extends Intent {
  const _ScrollToExtentIntent({required this.up});
  final bool up;
}

class _CopyTerminalIntent extends Intent {
  const _CopyTerminalIntent();
}

enum _TerminalMenuAction {
  copySelection,
  copyAll,
  paste,
  selectAll,
  clear,
}

class ComposeLogsTerminal extends StatefulWidget {
  const ComposeLogsTerminal({
    super.key,
    required this.composeBase,
    required this.project,
    required this.services,
    this.host,
    this.shellService,
    this.onExit,
    this.optionsController,
    required this.tailLines,
    this.settingsController,
  });

  final String composeBase;
  final String project;
  final List<String> services;
  final SshHost? host;
  final RemoteShellService? shellService;
  final VoidCallback? onExit;
  final TabOptionsController? optionsController;
  final int tailLines;
  final AppSettingsController? settingsController;

  @override
  State<ComposeLogsTerminal> createState() => _ComposeLogsTerminalState();
}

class _ComposeLogsTerminalState extends State<ComposeLogsTerminal> {
  bool _excludeSelection = false;
  final Set<String> _selected = {};
  int _restartToken = 0;
  int get _tailLines {
    final value = widget.tailLines;
    if (value < 0) return 0;
    if (value > 5000) return 5000;
    return value;
  }

  @override
  void initState() {
    super.initState();
    _queueTabOptionsUpdate();
  }

  @override
  void didUpdateWidget(covariant ComposeLogsTerminal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.optionsController != widget.optionsController ||
        oldWidget.project != widget.project ||
        oldWidget.composeBase != widget.composeBase ||
        oldWidget.services != widget.services) {
      _queueTabOptionsUpdate();
    }
  }

  @override
  Widget build(BuildContext context) {
    final serviceItems = widget.services;
    _selected.removeWhere((s) => !serviceItems.contains(s));
    final command = _buildCommand();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: DockerCommandTerminal(
            key: ValueKey('$command-$_restartToken'),
            command: command,
            title: 'Compose logs • ${widget.project}',
            host: widget.host,
            shellService: widget.shellService,
            showCopyButton: true,
            autofocus: false,
            onExit: widget.onExit,
            optionsController: widget.optionsController,
            settingsController: widget.settingsController,
          ),
        ),
      ],
    );
  }

  String _buildCommand() {
    final tailArg = '--tail $_tailLines';
    if (widget.services.isEmpty || _selected.isEmpty) {
      return '${widget.composeBase} logs -f $tailArg; exit';
    }
    final includeList = _excludeSelection
        ? widget.services.where((s) => !_selected.contains(s)).toList()
        : _selected.toList();
    if (includeList.isEmpty) {
      return '${widget.composeBase} logs -f $tailArg; exit';
    }
    final servicesArg = includeList.map((s) => '"$s"').join(' ');
    return '${widget.composeBase} logs -f $tailArg $servicesArg; exit';
  }

  void _restartLogs() {
    setState(() => _restartToken += 1);
    _updateTabOptions();
  }

  Future<void> _showServiceDialog() async {
    if (widget.services.isEmpty) {
      return;
    }
    final serviceItems = widget.services;
    final dialogSelected = Set<String>.from(_selected);
    var dialogExcludeSelection = _excludeSelection;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Filter services'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (serviceItems.isEmpty)
                          const Text('No services detected')
                        else
                          ...serviceItems.map(
                            (service) => FilterChip(
                              label: Text(service),
                              selected: dialogSelected.contains(service),
                              onSelected: (value) => setState(() {
                                if (value) {
                                  dialogSelected.add(service);
                                } else {
                                  dialogSelected.remove(service);
                                }
                              }),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text('Exclude selected'),
                        Switch(
                          value: dialogExcludeSelection,
                          onChanged: (value) =>
                              setState(() => dialogExcludeSelection = value),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => setState(
                            () => dialogSelected.addAll(serviceItems),
                          ),
                          child: const Text('Select all'),
                        ),
                        TextButton(
                          onPressed: () =>
                              setState(() => dialogSelected.clear()),
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
    if (result != true) {
      return;
    }
    setState(() {
      _selected
        ..clear()
        ..addAll(dialogSelected);
      _excludeSelection = dialogExcludeSelection;
      _restartToken += 1;
    });
    _updateTabOptions();
  }

  void _updateTabOptions() {
    final controller = widget.optionsController;
    if (controller == null) {
      return;
    }
    final overlay = [
      TabChipOption(
        label: 'Services…',
        icon: Icons.filter_list,
        onSelected: _showServiceDialog,
      ),
      TabChipOption(
        label: 'Restart tail',
        icon: Icons.refresh,
        onSelected: _restartLogs,
      ),
    ];
    if (controller is CompositeTabOptionsController) {
      controller.updateOverlay(overlay);
      return;
    }
    controller.update(overlay);
  }

  void _queueTabOptionsUpdate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _updateTabOptions();
    });
  }
}
