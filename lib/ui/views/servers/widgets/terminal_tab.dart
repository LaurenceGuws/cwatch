import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:general_lib/event_emitter/event_emitter.dart';
import 'package:terminal_library/pty_library/pty_library.dart';
import 'package:terminal_library/xterm_library/xterm.dart';

import '../../../../models/ssh_host.dart';
import '../../../../services/ssh/remote_shell_service.dart';
import '../../../../services/ssh/builtin/builtin_remote_shell_service.dart';
import '../../../theme/nerd_fonts.dart';

/// Terminal tab that spawns an SSH session via a PTY.
class TerminalTab extends StatefulWidget {
  const TerminalTab({
    super.key,
    required this.host,
    this.initialDirectory,
    required this.shellService,
  });

  final SshHost host;
  final String? initialDirectory;
  final RemoteShellService shellService;

  @override
  State<TerminalTab> createState() => _TerminalTabState();
}

class _TerminalTabState extends State<TerminalTab> {
  final TerminalLibraryFlutterController _controller =
      TerminalLibraryFlutterController();
  final TerminalLibraryFlutter _terminal = TerminalLibraryFlutter(maxLines: 1000);
  TerminalPtyLibraryBase? _pty;
  EventEmitterListener? _outputListener;
  bool _connecting = true;
  String? _error;
  final TerminalLibraryFlutterStyle _textStyle = const TerminalLibraryFlutterStyle(
    fontFamily: 'JetBrainsMonoNF',
    fontSize: 14,
    height: 1.1,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startSession());
  }

  @override
  void dispose() {
    _resetSession();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _startSession() async {
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
      _outputListener = session.on(
        eventName: session.event_output,
        onCallback: (data, _) => _handlePtyData(data),
      );

      _terminal.textInput('clear');
      _terminal.keyInput(TerminalLibraryFlutterKey.enter);
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
    return TerminalSessionOptions(
      columns: columns,
      rows: rows,
    );
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

  void _handlePtyData(dynamic data) {
    if (data is Uint8List) {
      try {
        final text = utf8.decode(data, allowMalformed: true);
        if (text.isNotEmpty) {
          _terminal.write(text);
        }
      } catch (_) {
        // Ignore decode errors
      }
      return;
    }
    if (data is String && data.isNotEmpty) {
      _terminal.write(data);
    }
  }

  void _onTerminalOutput(String value) {
    final bytes = utf8.encode(value);
    if (bytes.isEmpty) {
      return;
    }
    _pty?.write(Uint8List.fromList(bytes));
  }

  void _onTerminalResize(int columns, int rows, int pixelWidth, int pixelHeight) {
    _pty?.resize(rows, columns);
  }

  void _resetSession() {
    _outputListener?.cancel();
    _outputListener = null;
    _pty?.event_emitter.clear();
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
          Text(
            _error ?? 'Unknown error',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _startSession,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_connecting) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _buildError(context);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context),
        const Divider(height: 1),
        Expanded(
          child: TerminalLibraryFlutterViewWidget(
            _terminal,
            controller: _controller,
            autofocus: true,
            backgroundOpacity: 1,
            simulateScroll: true,
            padding: EdgeInsets.zero,
            alwaysShowCursor: true,
            deleteDetection:
                defaultTargetPlatform == TargetPlatform.android ||
                    defaultTargetPlatform == TargetPlatform.iOS,
            textStyle: _textStyle,
          ),
        ),
      ],
    );
  }
}
