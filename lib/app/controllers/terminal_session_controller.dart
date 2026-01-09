import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cwatch/models/ssh_host.dart';
import 'package:cwatch/services/ssh/remote_shell_service.dart';
import 'package:cwatch/services/ssh/terminal_session.dart';

class TerminalSessionController {
  TerminalSessionController({required this.shellService, required this.host});

  final RemoteShellService shellService;
  final SshHost host;
  TerminalSession? _session;
  StreamSubscription<String>? _outputSub;

  Future<TerminalSession> start({
    required TerminalSessionOptions options,
    required void Function(String text) onOutput,
    required void Function(int exitCode) onExit,
  }) async {
    final session = await shellService.createTerminalSession(
      host,
      options: options,
    );
    _session = session;
    await _outputSub?.cancel();
    _outputSub = const Utf8Decoder(
      allowMalformed: true,
    ).bind(session.output).listen(onOutput);
    unawaited(session.exitCode.then(onExit));
    return session;
  }

  void write(Uint8List data) {
    _session?.write(data);
  }

  void resize(int rows, int cols) {
    _session?.resize(rows, cols);
  }

  void reset() {
    _session?.kill();
    _session = null;
    _outputSub?.cancel();
    _outputSub = null;
  }

  void dispose() {
    reset();
  }
}
