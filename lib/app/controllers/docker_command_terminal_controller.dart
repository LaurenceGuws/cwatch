import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:cwatch/models/ssh_host.dart';
import 'package:cwatch/services/ssh/remote_shell_service.dart';
import 'package:cwatch/services/ssh/terminal_session.dart';
import 'package:cwatch/shared/shell/local_shell.dart';
import 'package:cwatch/services/logging/app_logger.dart';

class DockerCommandTerminalController extends ChangeNotifier {
  DockerCommandTerminalController({
    required this.command,
    this.host,
    this.shellService,
  });

  final String command;
  final SshHost? host;
  final RemoteShellService? shellService;

  TerminalSession? session;
  StreamSubscription<String>? outputSub;
  bool connecting = true;
  String? error;
  int sessionToken = 0;
  final StringBuffer outputBuffer = StringBuffer();

  Future<TerminalSession> start({
    required TerminalSessionOptions options,
    required void Function(String text) onOutput,
    required void Function() onExit,
  }) async {
    sessionToken += 1;
    final token = sessionToken;
    connecting = true;
    error = null;
    outputBuffer.clear();
    notifyListeners();

    try {
      final newSession = host != null && shellService != null
          ? await shellService!.createTerminalSession(
              host!,
              options: options,
            )
          : LocalPtySession(
              executable: _localShell.executable,
              arguments: _localShell.arguments,
              cols: options.columns,
              rows: options.rows,
            );

      if (token != sessionToken) {
        newSession.kill();
        throw Exception('Session cancelled');
      }

      session = newSession;
      await outputSub?.cancel();
      outputSub = const Utf8Decoder(allowMalformed: true)
          .bind(newSession.output)
          .listen((text) {
        if (text.isEmpty) return;
        onOutput(text);
        outputBuffer.write(text);
      });

      unawaited(newSession.exitCode.then((_) {
        if (token == sessionToken) {
          onExit();
        }
      }));

      connecting = false;
      notifyListeners();
      return newSession;
    } catch (e, stackTrace) {
      AppLogger().warn(
        'Docker command terminal failed',
        tag: 'DockerTerminal',
        error: e,
        stackTrace: stackTrace,
      );
      error = e.toString();
      connecting = false;
      notifyListeners();
      rethrow;
    }
  }

  void writeCommand(String commandText) {
    final bytes = utf8.encode('$commandText\n');
    session?.write(Uint8List.fromList(bytes));
    outputBuffer.write('$commandText\n');
  }

  void write(Uint8List data) {
    session?.write(data);
  }

  void resize(int rows, int cols) {
    session?.resize(rows, cols);
  }

  void reset() {
    session?.kill();
    session = null;
    outputSub?.cancel();
    outputSub = null;
    outputBuffer.clear();
    connecting = false;
    error = null;
    notifyListeners();
  }

  LocalShellDefinition get _localShell =>
      LocalShellResolver().forPlatform(defaultTargetPlatform);

  @override
  void dispose() {
    reset();
    super.dispose();
  }
}
