import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';
import 'package:cwatch/services/ssh/terminal_session.dart';

import '../../../../models/app_settings.dart';
import '../../../../models/ssh_host.dart';
import '../../../../services/ssh/remote_shell_service.dart';
import '../../../../services/settings/app_settings_controller.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/nerd_fonts.dart';
import '../../shared/tabs/terminal/terminal_theme_presets.dart';

/// Lightweight terminal view that runs a provided Docker command locally or via SSH.
class DockerCommandTerminal extends StatefulWidget {
  const DockerCommandTerminal({
    super.key,
    required this.command,
    required this.title,
    this.host,
    this.shellService,
    this.settingsController,
    this.actions,
    this.showCopyButton = true,
    this.autofocus = true,
    this.onExit,
  });

  final SshHost? host;
  final RemoteShellService? shellService;
  final String command;
  final String title;
  final List<Widget>? actions;
  final AppSettingsController? settingsController;
  final bool showCopyButton;
  final bool autofocus;
  final VoidCallback? onExit;

  @override
  State<DockerCommandTerminal> createState() => _DockerCommandTerminalState();
}

class _DockerCommandTerminalState extends State<DockerCommandTerminal> {
  final TerminalController _controller = TerminalController();
  final Terminal _terminal = Terminal(maxLines: 1000);
  final ScrollController _scrollController = ScrollController();
  TerminalSession? _pty;
  StreamSubscription<Uint8List>? _outputSub;
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _pty?.kill();
    _outputSub?.cancel();
    _controller.removeListener(_logSelectionChange);
    _scrollController.removeListener(_logScrollChange);
    _scrollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant DockerCommandTerminal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.command != widget.command || oldWidget.host != widget.host) {
      _start();
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
      if (widget.host != null && widget.shellService != null) {
        final session = await widget.shellService!.createTerminalSession(
          widget.host!,
          options: _sessionOptions(),
        );
        if (token != _sessionToken) {
          session.kill();
          return;
        }
        _pty = session;
        _outputSub?.cancel();
        _outputSub = session.output.listen(_handlePtyData);
        unawaited(
          session.exitCode.then((_) {
            if (!mounted || token != _sessionToken) return;
            widget.onExit?.call();
          }),
        );
        _terminal.textInput('${widget.command}\n');
      } else {
        final session = LocalPtySession(
          executable: 'bash',
          arguments: ['-lc', widget.command],
          cols: _sessionOptions().columns,
          rows: _sessionOptions().rows,
        );
        if (token != _sessionToken) {
          session.kill();
          return;
        }
        _pty = session;
        _outputSub?.cancel();
        _outputSub = session.output.listen(_handlePtyData);
        unawaited(
          session.exitCode.then((_) {
            if (!mounted || token != _sessionToken) return;
            widget.onExit?.call();
          }),
        );
      }
      setState(() => _connecting = false);
    } catch (error, stack) {
      debugPrint('DockerCommandTerminal failed: $error\n$stack');
      setState(() {
        _connecting = false;
        _error = error.toString();
      });
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

  void _handlePtyData(Uint8List data) {
    if (data.isEmpty) return;
    final text = utf8.decode(data, allowMalformed: true);
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(NerdIcon.terminal.data, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.title,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              if (widget.showCopyButton)
                IconButton(
                  tooltip: 'Copy output',
                  icon: Icon(context.appTheme.icons.copy),
                  onPressed: _copyOutput,
                ),
              ...?widget.actions,
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: Shortcuts(
            shortcuts: {
              LogicalKeySet(
                LogicalKeyboardKey.control,
                LogicalKeyboardKey.shift,
                LogicalKeyboardKey.arrowUp,
              ): const _ScrollByIntent(
                -160,
              ),
              LogicalKeySet(
                LogicalKeyboardKey.control,
                LogicalKeyboardKey.shift,
                LogicalKeyboardKey.arrowDown,
              ): const _ScrollByIntent(
                160,
              ),
              LogicalKeySet(
                LogicalKeyboardKey.control,
                LogicalKeyboardKey.shift,
                LogicalKeyboardKey.pageUp,
              ): const _ScrollByIntent(
                -480,
              ),
              LogicalKeySet(
                LogicalKeyboardKey.control,
                LogicalKeyboardKey.shift,
                LogicalKeyboardKey.pageDown,
              ): const _ScrollByIntent(
                480,
              ),
              LogicalKeySet(
                LogicalKeyboardKey.control,
                LogicalKeyboardKey.shift,
                LogicalKeyboardKey.home,
              ): const _ScrollToExtentIntent(
                up: true,
              ),
              LogicalKeySet(
                LogicalKeyboardKey.control,
                LogicalKeyboardKey.shift,
                LogicalKeyboardKey.end,
              ): const _ScrollToExtentIntent(
                up: false,
              ),
              LogicalKeySet(
                LogicalKeyboardKey.control,
                LogicalKeyboardKey.shift,
                LogicalKeyboardKey.keyC,
              ): const _CopyTerminalIntent(),
            },
            child: Actions(
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
                autofocus: widget.autofocus,
                alwaysShowCursor: true,
                textStyle: _textStyle(settings),
                theme: _terminalTheme(context, settings),
              ),
            ),
          ),
        ),
      ],
    );
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
      return;
    }
    final text = _safeSelectionText(selection);
    final signature = '${selection.begin}-${selection.end}|${text.hashCode}';
    if (!force && signature == _lastSelectionSignature) {
      return;
    }
    _lastSelectionSignature = signature;
  }

  TerminalStyle _textStyle(AppSettings? settings) {
    final fontSize = (settings?.terminalFontSize ?? 14).clamp(8, 32).toDouble();
    final lineHeight = (settings?.terminalLineHeight ?? 1.4)
        .clamp(0.8, 2.0)
        .toDouble();
    return TerminalStyle(
      fontFamily: NerdFonts.effectiveFamily(settings?.terminalFontFamily),
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

class ComposeLogsTerminal extends StatefulWidget {
  const ComposeLogsTerminal({
    super.key,
    required this.composeBase,
    required this.project,
    required this.services,
    this.host,
    this.shellService,
    this.onExit,
  });

  final String composeBase;
  final String project;
  final List<String> services;
  final SshHost? host;
  final RemoteShellService? shellService;
  final VoidCallback? onExit;

  @override
  State<ComposeLogsTerminal> createState() => _ComposeLogsTerminalState();
}

class _ComposeLogsTerminalState extends State<ComposeLogsTerminal> {
  bool _excludeSelection = false;
  final Set<String> _selected = {};

  @override
  Widget build(BuildContext context) {
    final serviceItems = widget.services;
    _selected.removeWhere((s) => !serviceItems.contains(s));
    final command = _buildCommand();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Services',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (serviceItems.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text('None detected'),
                      )
                    else
                      ...serviceItems.map(
                        (service) => FilterChip(
                          label: Text(service),
                          selected: _selected.contains(service),
                          onSelected: (value) {
                            setState(() {
                              if (value) {
                                _selected.add(service);
                              } else {
                                _selected.remove(service);
                              }
                            });
                          },
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (serviceItems.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        const Text('Exclude selected'),
                        Switch(
                          value: _excludeSelection,
                          onChanged: (value) =>
                              setState(() => _excludeSelection = value),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () =>
                              setState(() => _selected.addAll(serviceItems)),
                          child: const Text('Select all'),
                        ),
                        TextButton(
                          onPressed: () => setState(() => _selected.clear()),
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
                  ],
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: DockerCommandTerminal(
            key: ValueKey(command),
            command: command,
            title: 'Compose logs • ${widget.project}',
            host: widget.host,
            shellService: widget.shellService,
            showCopyButton: true,
            autofocus: false,
            onExit: widget.onExit,
          ),
        ),
      ],
    );
  }

  String _buildCommand() {
    if (widget.services.isEmpty || _selected.isEmpty) {
      return '${widget.composeBase} logs -f --tail 200; exit';
    }
    final includeList = _excludeSelection
        ? widget.services.where((s) => !_selected.contains(s)).toList()
        : _selected.toList();
    if (includeList.isEmpty) {
      return '${widget.composeBase} logs -f --tail 200; exit';
    }
    final servicesArg = includeList.map((s) => '"$s"').join(' ');
    return '${widget.composeBase} logs -f --tail 200 $servicesArg; exit';
  }
}
