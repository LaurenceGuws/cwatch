import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_pty/flutter_pty.dart';
import 'package:path/path.dart' as p;

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
    _registry.register(_pty.pid);
    _exitCode.then((_) => _registry.unregister(_pty.pid));
  }

  final Pty _pty;
  late final Future<int> _exitCode;
  static final _registry = _LocalPtyRegistry();

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
    _registry.unregister(_pty.pid);
  }

  static Future<void> cleanupStaleSessions() {
    return _registry.cleanup();
  }
}

class _LocalPtyRegistry {
  _LocalPtyRegistry()
    : _pidFile = File(
        p.join(Directory.systemTemp.path, 'cwatch', 'pty_pids.json'),
      );

  final File _pidFile;

  Future<Set<int>> _load() async {
    try {
      if (!await _pidFile.exists()) return {};
      final raw = await _pidFile.readAsString();
      final parts = raw.split(',').where((p) => p.isNotEmpty);
      return parts.map((p) => int.tryParse(p)).whereType<int>().toSet();
    } catch (_) {
      return {};
    }
  }

  Future<void> _persist(Set<int> pids) async {
    try {
      await _pidFile.parent.create(recursive: true);
      await _pidFile.writeAsString(pids.join(','));
    } catch (_) {
      // ignore persistence errors; registry is best-effort
    }
  }

  Future<void> register(int pid) async {
    final pids = await _load();
    pids.add(pid);
    await _persist(pids);
  }

  Future<void> unregister(int pid) async {
    final pids = await _load();
    if (pids.remove(pid)) {
      await _persist(pids);
    }
  }

  Future<void> cleanup() async {
    final pids = await _load();
    if (pids.isEmpty) return;

    final survivors = <int>{};
    for (final pid in pids) {
      final killed = Process.killPid(pid, ProcessSignal.sigterm);
      if (killed) {
        continue;
      }
      final forceKilled = Process.killPid(pid, ProcessSignal.sigkill);
      if (!forceKilled) {
        survivors.add(pid);
      }
    }
    await _persist(survivors);
  }
}
