import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_pty/flutter_pty.dart';

/// Minimal PTY-backed terminal session interface.
abstract class TerminalSession {
  Stream<Uint8List> get output;
  Future<int> get exitCode;
  void write(Uint8List data);
  void resize(int rows, int cols);
  void kill();
}

class LocalPtySession implements TerminalSession {
  LocalPtySession({
    required String executable,
    required List<String> arguments,
    required int rows,
    required int cols,
    Map<String, String>? environment,
    String? workingDirectory,
  }) : _pty = Pty.start(
          executable,
          arguments: arguments,
          columns: cols,
          rows: rows,
          environment: environment,
          workingDirectory: workingDirectory,
        ) {
    _exitCode = _pty.exitCode;
  }

  final Pty _pty;
  late final Future<int> _exitCode;

  @override
  Stream<Uint8List> get output => _pty.output;

  @override
  Future<int> get exitCode => _exitCode;

  @override
  void write(Uint8List data) {
    _pty.write(data);
  }

  @override
  void resize(int rows, int cols) {
    _pty.resize(rows, cols);
  }

  @override
  void kill() {
    try {
      _pty.kill();
    } catch (_) {
      // ignore
    }
  }
}
