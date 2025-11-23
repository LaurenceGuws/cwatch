import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:terminal_library/pty_library/pty_library.dart';
import 'package:terminal_library/xterm_library/xterm.dart';

import '../../../../models/ssh_host.dart';
import '../../../../services/ssh/remote_shell_service.dart';
import '../../../theme/nerd_fonts.dart';

/// Lightweight terminal view that runs a provided Docker command over SSH.
class DockerCommandTerminal extends StatefulWidget {
  const DockerCommandTerminal({
    super.key,
    required this.host,
    required this.shellService,
    required this.command,
    required this.title,
  });

  final SshHost host;
  final RemoteShellService shellService;
  final String command;
  final String title;

  @override
  State<DockerCommandTerminal> createState() => _DockerCommandTerminalState();
}

class _DockerCommandTerminalState extends State<DockerCommandTerminal> {
  final TerminalLibraryFlutterController _controller =
      TerminalLibraryFlutterController();
  final TerminalLibraryFlutter _terminal = TerminalLibraryFlutter(maxLines: 1000);
  TerminalPtyLibraryBase? _pty;
  bool _connecting = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _pty?.kill();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _connecting = true;
      _error = null;
    });
    _terminal.onOutput = _onOutput;
    _terminal.onResize = _onResize;
    _terminal.buffer.clear();
    try {
      final session = await widget.shellService.createTerminalSession(
        widget.host,
        options: _sessionOptions(),
      );
      _pty = session;
      session.on(
        eventName: session.event_output,
        onCallback: (data, _) => _handlePtyData(data),
      );
      _terminal.textInput('${widget.command}\n');
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
    return TerminalSessionOptions(columns: columns, rows: rows);
  }

  void _handlePtyData(dynamic data) {
    if (data is Uint8List) {
      final text = utf8.decode(data, allowMalformed: true);
      _terminal.write(text);
    } else if (data is String) {
      _terminal.write(data);
    }
  }

  void _onOutput(String value) {
    final bytes = utf8.encode(value);
    if (bytes.isEmpty) return;
    _pty?.write(Uint8List.fromList(bytes));
  }

  void _onResize(int columns, int rows, int pixelWidth, int pixelHeight) {
    _pty?.resize(rows, columns);
  }

  @override
  Widget build(BuildContext context) {
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
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: TerminalLibraryFlutterViewWidget(
            _terminal,
            controller: _controller,
            autofocus: true,
            simulateScroll: true,
            alwaysShowCursor: true,
          ),
        ),
      ],
    );
  }
}
