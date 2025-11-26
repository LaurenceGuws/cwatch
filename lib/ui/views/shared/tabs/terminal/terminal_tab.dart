import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';
import 'package:cwatch/services/ssh/terminal_session.dart';

import '../../../../../models/app_settings.dart';
import '../../../../../models/ssh_host.dart';
import '../../../../../services/ssh/remote_shell_service.dart';
import '../../../../../services/ssh/builtin/builtin_remote_shell_service.dart';
import '../../../../../services/settings/app_settings_controller.dart';
import '../../../../theme/nerd_fonts.dart';
import 'terminal_theme_presets.dart';

/// Terminal tab that spawns an SSH session via a PTY.
class TerminalTab extends StatefulWidget {
  const TerminalTab({
    super.key,
    required this.host,
    this.initialDirectory,
    required this.shellService,
    required this.settingsController,
    this.onExit,
  });

  final SshHost host;
  final String? initialDirectory;
  final RemoteShellService shellService;
  final AppSettingsController settingsController;
  final VoidCallback? onExit;

  @override
  State<TerminalTab> createState() => _TerminalTabState();
}

class _TerminalTabState extends State<TerminalTab> {
  final TerminalController _controller = TerminalController();
  final Terminal _terminal = Terminal(maxLines: 1000);
  TerminalSession? _pty;
  bool _connecting = true;
  String? _error;
  bool _closing = false;
  int _sessionToken = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startSession());
  }

  @override
  void dispose() {
    _closing = true;
    _resetSession();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _startSession() async {
    _sessionToken += 1;
    final token = _sessionToken;
    _closing = false;
    _resetSession();
    setState(() {
      _connecting = true;
      _error = null;
    });

    _terminal.onOutput = _onTerminalOutput;
    _terminal.onResize = _onTerminalResize;
    _terminal.buffer.clear();
    _terminal.buffer.setCursor(0, 0);

    try {
      final session = await widget.shellService.createTerminalSession(
        widget.host,
        options: _terminalSessionOptions(),
      );
      _pty = session;
      session.output.listen(_handlePtyData);
      unawaited(
        session.exitCode.then((_) {
          if (!mounted || _closing || token != _sessionToken) return;
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

  void _handlePtyData(Uint8List data) {
    if (data.isEmpty) {
      return;
    }
    try {
      final text = utf8.decode(data, allowMalformed: true);
      if (text.isNotEmpty) {
        _terminal.write(text);
      }
    } catch (_) {
      // Ignore decode errors
    }
  }

  void _resetSession() {
    _pty?.kill();
    _pty = null;
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

  Widget _buildHeader(BuildContext context) {
    final hostLabel = widget.initialDirectory?.trim().isNotEmpty == true
        ? widget.initialDirectory!.trim()
        : '~';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Icon(NerdIcon.terminal.data, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${widget.host.name} • $hostLabel',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          IconButton(
            tooltip: 'Restart terminal',
            icon: const Icon(Icons.refresh),
            onPressed: _startSession,
          ),
        ],
      ),
    );
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
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                const Divider(height: 1),
                Expanded(
                  child: TerminalView(
                    _terminal,
                    controller: _controller,
                    autofocus: true,
                    backgroundOpacity: 1,
                    padding: EdgeInsets.zero,
                    alwaysShowCursor: true,
                    deleteDetection:
                        defaultTargetPlatform == TargetPlatform.android ||
                        defaultTargetPlatform == TargetPlatform.iOS,
                    textStyle: _textStyle(settings),
                    theme: _terminalTheme(context, settings),
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
      fontFamily: NerdFonts.effectiveFamily(settings.terminalFontFamily),
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
}
