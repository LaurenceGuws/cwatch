import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:cwatch/models/remote_file_entry.dart';
import 'package:cwatch/models/ssh_host.dart';
import 'package:cwatch/services/ssh/remote_shell_service.dart';
import 'package:cwatch/services/ssh/terminal_session.dart';

/// Remote shell wrapper that executes commands inside a Docker container over SSH.
class DockerContainerShellService extends RemoteShellService {
  DockerContainerShellService({
    required this.host,
    required this.containerId,
    required this.baseShell,
  });

  final SshHost host;
  final String containerId;
  final RemoteShellService baseShell;

  @override
  Future<List<RemoteFileEntry>> listDirectory(
    SshHost host,
    String path, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final output = await runCommand(
      host,
      'ls -la --time-style=+%Y-%m-%dT%H:%M:%S ${_escape(path)}',
      timeout: timeout,
    );
    return parseLsOutput(output);
  }

  @override
  Future<String> homeDirectory(
    SshHost host, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final output = await runCommand(
      host,
      r'printf %s "$HOME"',
      timeout: timeout,
    );
    return output.trim().isEmpty ? '/' : output.trim();
  }

  @override
  Future<String> readFile(
    SshHost host,
    String path, {
    Duration timeout = const Duration(seconds: 15),
  }) {
    return runCommand(host, 'cat ${_escape(path)}', timeout: timeout);
  }

  @override
  Future<void> writeFile(
    SshHost host,
    String path,
    String contents, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final tempDir = await _makeTempDir(timeout: timeout);
    try {
      final tempFile = p.join(tempDir, p.basename(path));
      await baseShell.writeFile(
        this.host,
        tempFile,
        contents,
        timeout: timeout,
      );
      await baseShell.runCommand(
        this.host,
        'docker cp ${_escapeLocal(tempFile)} $containerId:${_escape(path)}',
        timeout: timeout,
      );
    } finally {
      await _cleanupTemp(tempDir);
    }
  }

  @override
  Future<void> movePath(
    SshHost host,
    String source,
    String destination, {
    Duration timeout = const Duration(seconds: 15),
  }) {
    return runCommand(
      host,
      'mv ${_escape(source)} ${_escape(destination)}',
      timeout: timeout,
    );
  }

  @override
  Future<void> copyPath(
    SshHost host,
    String source,
    String destination, {
    bool recursive = false,
    Duration timeout = const Duration(seconds: 20),
  }) {
    final flag = recursive ? '-r' : '';
    return runCommand(
      host,
      'cp $flag ${_escape(source)} ${_escape(destination)}',
      timeout: timeout,
    );
  }

  @override
  Future<void> deletePath(
    SshHost host,
    String path, {
    Duration timeout = const Duration(seconds: 15),
  }) {
    return runCommand(host, 'rm -rf ${_escape(path)}', timeout: timeout);
  }

  @override
  Future<void> copyBetweenHosts({
    required SshHost sourceHost,
    required String sourcePath,
    required SshHost destinationHost,
    required String destinationPath,
    bool recursive = false,
    Duration timeout = const Duration(minutes: 2),
  }) {
    return Future.error(
      Exception('Cross-host copy is not supported for container sessions'),
    );
  }

  @override
  Future<void> downloadPath({
    required SshHost host,
    required String remotePath,
    required String localDestination,
    bool recursive = false,
    Duration timeout = const Duration(minutes: 2),
  }) async {
    final tempDir = await _makeTempDir(timeout: timeout);
    try {
      await baseShell.runCommand(
        this.host,
        'docker cp $containerId:${_escape(remotePath)} ${_escapeLocal(tempDir)}',
        timeout: timeout,
      );
      final payload = p.join(tempDir, p.basename(remotePath));
      await baseShell.downloadPath(
        host: this.host,
        remotePath: payload,
        localDestination: localDestination,
        recursive: recursive,
        timeout: timeout,
      );
    } finally {
      await _cleanupTemp(tempDir);
    }
  }

  @override
  Future<void> uploadPath({
    required SshHost host,
    required String localPath,
    required String remoteDestination,
    bool recursive = false,
    Duration timeout = const Duration(minutes: 2),
  }) async {
    final tempDir = await _makeTempDir(timeout: timeout);
    try {
      final tempDest = p.join(tempDir, p.basename(localPath));
      await baseShell.uploadPath(
        host: this.host,
        localPath: localPath,
        remoteDestination: tempDest,
        recursive: recursive,
        timeout: timeout,
      );
      await baseShell.runCommand(
        this.host,
        'docker cp ${_escapeLocal(tempDest)} $containerId:${_escape(remoteDestination)}',
        timeout: timeout,
      );
    } finally {
      await _cleanupTemp(tempDir);
    }
  }

  @override
  Future<String> runCommand(
    SshHost host,
    String command, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final wrapped =
        'docker exec $containerId sh -lc ${_escapeSingleCommand(command)}';
    return baseShell.runCommand(this.host, wrapped, timeout: timeout);
  }

  @override
  Future<TerminalSession> createTerminalSession(
    SshHost host, {
    required TerminalSessionOptions options,
  }) {
    throw UnimplementedError(
      'Terminal sessions are not supported from explorer for containers.',
    );
  }

  Future<String> _makeTempDir({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final output = await baseShell.runCommand(
      host,
      'mktemp -d /tmp/cwatch-dctr-XXXXXX',
      timeout: timeout,
    );
    return output.trim();
  }

  Future<void> _cleanupTemp(String tempDir) async {
    await baseShell.runCommand(
      host,
      'rm -rf ${_escapeLocal(tempDir)}',
      timeout: const Duration(seconds: 5),
    );
  }

  String _escape(String path) => "'${path.replaceAll("'", "\\'")}'";
  String _escapeLocal(String path) => path.replaceAll(' ', '\\ ');

  String _escapeSingleCommand(String command) {
    return "'${command.replaceAll("'", "'\\''")}'";
  }
}

/// Local-only Docker container shell that proxies through the Docker CLI.
class LocalDockerContainerShellService extends RemoteShellService {
  LocalDockerContainerShellService({
    required this.containerId,
    this.contextName,
  });

  final String containerId;
  final String? contextName;

  @override
  Future<List<RemoteFileEntry>> listDirectory(
    SshHost host,
    String path, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final output = await runCommand(
      host,
      'ls -la --time-style=+%Y-%m-%dT%H:%M:%S ${_escape(path)}',
      timeout: timeout,
    );
    return parseLsOutput(output);
  }

  @override
  Future<String> homeDirectory(
    SshHost host, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final output = await runCommand(
      host,
      r'printf %s "$HOME"',
      timeout: timeout,
    );
    return output.trim().isEmpty ? '/' : output.trim();
  }

  @override
  Future<String> readFile(
    SshHost host,
    String path, {
    Duration timeout = const Duration(seconds: 15),
  }) {
    return runCommand(host, 'cat ${_escape(path)}', timeout: timeout);
  }

  @override
  Future<void> writeFile(
    SshHost host,
    String path,
    String contents, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final tempDir = await Directory.systemTemp.createTemp('cwatch-dctr');
    try {
      final tempFile = File(p.join(tempDir.path, p.basename(path)));
      await tempFile.writeAsString(contents);
      await _runDocker([
        'cp',
        tempFile.path,
        '$containerId:${_escapeBare(path)}',
      ], timeout: timeout);
    } finally {
      await tempDir.delete(recursive: true);
    }
  }

  @override
  Future<void> movePath(
    SshHost host,
    String source,
    String destination, {
    Duration timeout = const Duration(seconds: 15),
  }) {
    return runCommand(
      host,
      'mv ${_escape(source)} ${_escape(destination)}',
      timeout: timeout,
    );
  }

  @override
  Future<void> copyPath(
    SshHost host,
    String source,
    String destination, {
    bool recursive = false,
    Duration timeout = const Duration(seconds: 20),
  }) {
    final flag = recursive ? '-r' : '';
    return runCommand(
      host,
      'cp $flag ${_escape(source)} ${_escape(destination)}',
      timeout: timeout,
    );
  }

  @override
  Future<void> deletePath(
    SshHost host,
    String path, {
    Duration timeout = const Duration(seconds: 15),
  }) {
    return runCommand(host, 'rm -rf ${_escape(path)}', timeout: timeout);
  }

  @override
  Future<void> copyBetweenHosts({
    required SshHost sourceHost,
    required String sourcePath,
    required SshHost destinationHost,
    required String destinationPath,
    bool recursive = false,
    Duration timeout = const Duration(minutes: 2),
  }) {
    return Future.error(
      Exception('Cross-host copy is not supported for container sessions'),
    );
  }

  @override
  Future<void> downloadPath({
    required SshHost host,
    required String remotePath,
    required String localDestination,
    bool recursive = false,
    Duration timeout = const Duration(minutes: 2),
  }) async {
    await _runDocker([
      'cp',
      '$containerId:${_escapeBare(remotePath)}',
      localDestination,
    ], timeout: timeout);
  }

  @override
  Future<void> uploadPath({
    required SshHost host,
    required String localPath,
    required String remoteDestination,
    bool recursive = false,
    Duration timeout = const Duration(minutes: 2),
  }) {
    return _runDocker([
      'cp',
      localPath,
      '$containerId:${_escapeBare(remoteDestination)}',
    ], timeout: timeout);
  }

  @override
  Future<String> runCommand(
    SshHost host,
    String command, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final result = await _runDocker([
      'exec',
      containerId,
      'sh',
      '-lc',
      command,
    ], timeout: timeout);
    return result;
  }

  @override
  Future<TerminalSession> createTerminalSession(
    SshHost host, {
    required TerminalSessionOptions options,
  }) {
    throw UnimplementedError(
      'Terminal sessions are not supported from explorer for containers.',
    );
  }

  Future<String> _runDocker(
    List<String> args, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final commandArgs = <String>[];
    if (contextName?.trim().isNotEmpty == true) {
      commandArgs.addAll(['--context', contextName!.trim()]);
    }
    commandArgs.addAll(args);
    final result = await Process.run('docker', commandArgs).timeout(timeout);
    if (result.exitCode != 0) {
      throw Exception(
        'docker ${args.join(' ')} failed: ${(result.stderr as String? ?? '').trim()}',
      );
    }
    return (result.stdout as String? ?? '').trimRight();
  }

  String _escape(String path) => "'${path.replaceAll("'", "\\'")}'";
  String _escapeBare(String path) => path;
}
