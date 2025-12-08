import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';

import '../terminal_session.dart';

class BuiltInTerminalSession implements TerminalSession {
  BuiltInTerminalSession({
    required this.client,
    required this.session,
    required this.rows,
    required this.columns,
  }) {
    _stdoutSubscription = session.stdout.listen(
      _handleOutput,
      onError: (_) => _cleanup(),
      onDone: _cleanup,
    );
    _stderrSubscription = session.stderr.listen(
      _handleOutput,
      onError: (_) => _cleanup(),
      onDone: _cleanup,
    );
    session.done.then((_) => _cleanup());
  }

  final SSHClient client;
  final SSHSession session;
  final int rows;
  final int columns;
  final _outputController = StreamController<Uint8List>.broadcast();

  late final StreamSubscription<Uint8List> _stdoutSubscription;
  late final StreamSubscription<Uint8List> _stderrSubscription;
  bool _closed = false;

  void _handleOutput(Uint8List data) {
    if (data.isEmpty || _closed) {
      return;
    }
    _outputController.add(data);
  }

  void _cleanup() {
    if (_closed) {
      return;
    }
    _closed = true;
    _stdoutSubscription.cancel();
    _stderrSubscription.cancel();
    _outputController.close();
    session.close();
    client.close();
  }

  @override
  Stream<Uint8List> get output => _outputController.stream;

  @override
  Future<int> get exitCode async {
    await session.done;
    return 0;
  }

  @override
  void write(Uint8List data) {
    if (_closed) {
      return;
    }
    session.write(data);
  }

  @override
  void resize(int rows, int cols) {
    if (_closed) {
      return;
    }
    // SSH expects width (columns) first, then height (rows).
    session.resizeTerminal(cols, rows);
  }

  @override
  void kill() {
    if (_closed) {
      return;
    }
    session.kill(_mapSignal(ProcessSignal.sigterm));
    _cleanup();
  }

  SSHSignal _mapSignal(ProcessSignal signal) {
    switch (signal) {
      case ProcessSignal.sigint:
        return SSHSignal.INT;
      case ProcessSignal.sigkill:
        return SSHSignal.KILL;
      case ProcessSignal.sigterm:
        return SSHSignal.TERM;
      default:
        return SSHSignal.TERM;
    }
  }
}
