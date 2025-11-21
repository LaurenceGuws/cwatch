import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../models/remote_file_entry.dart';
import '../../models/ssh_host.dart';
import 'remote_command_observer.dart';
import 'remote_ls_parser.dart';

abstract class RemoteShellService {
  const RemoteShellService({
    this.debugMode = false,
    this.observer,
  });

  final bool debugMode;
  final RemoteCommandObserver? observer;

  @protected
  void emitDebugEvent({
    required SshHost host,
    required String operation,
    required String command,
    required String output,
    VerificationResult? verification,
  }) {
    if (!debugMode) {
      return;
    }
    observer?.call(
      RemoteCommandDebugEvent(
        host: host,
        operation: operation,
        command: command,
        output: output.trim(),
        verificationCommand: verification?.command,
        verificationOutput: verification?.output.trim(),
        verificationPassed: verification?.passed,
      ),
    );
    if (verification?.passed == false) {
      debugPrint(
        '[SSH DEBUG] Verification failed for $operation on ${host.name}',
      );
    }
  }

  Future<List<RemoteFileEntry>> listDirectory(
    SshHost host,
    String path, {
    Duration timeout = const Duration(seconds: 10),
  });

  Future<String> homeDirectory(
    SshHost host, {
    Duration timeout = const Duration(seconds: 5),
  });

  Future<String> readFile(
    SshHost host,
    String path, {
    Duration timeout = const Duration(seconds: 15),
  });

  Future<void> writeFile(
    SshHost host,
    String path,
    String contents, {
    Duration timeout = const Duration(seconds: 15),
  });

  Future<void> movePath(
    SshHost host,
    String source,
    String destination, {
    Duration timeout = const Duration(seconds: 15),
  });

  Future<void> copyPath(
    SshHost host,
    String source,
    String destination, {
    bool recursive = false,
    Duration timeout = const Duration(seconds: 20),
  });

  Future<void> deletePath(
    SshHost host,
    String path, {
    Duration timeout = const Duration(seconds: 15),
  });

  Future<void> copyBetweenHosts({
    required SshHost sourceHost,
    required String sourcePath,
    required SshHost destinationHost,
    required String destinationPath,
    bool recursive = false,
    Duration timeout = const Duration(minutes: 2),
  });

  Future<void> downloadPath({
    required SshHost host,
    required String remotePath,
    required String localDestination,
    bool recursive = false,
    Duration timeout = const Duration(minutes: 2),
  });

  Future<void> uploadPath({
    required SshHost host,
    required String localPath,
    required String remoteDestination,
    bool recursive = false,
    Duration timeout = const Duration(minutes: 2),
  });
}

class ProcessRemoteShellService extends RemoteShellService {
  const ProcessRemoteShellService({
    super.debugMode = false,
    super.observer,
  });

  /// Handles SSH command errors, detecting authentication failures.
  Never _handleSshError(SshHost host, ProcessResult result) {
    final stderrOutput = (result.stderr as String?)?.trim();
    final errorMessage = stderrOutput?.isNotEmpty == true
        ? stderrOutput
        : 'SSH exited with ${result.exitCode}';

    // Check for common authentication failure patterns
    if (stderrOutput?.contains('Permission denied') == true ||
        stderrOutput?.contains('Authentication failed') == true ||
        stderrOutput?.contains('Host key verification failed') == true ||
        result.exitCode == 255) {
      throw Exception('SSH authentication failed for ${host.name}: $errorMessage');
    }

    throw Exception(errorMessage);
  }

  @override
  Future<List<RemoteFileEntry>> listDirectory(
    SshHost host,
    String path, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final sanitizedPath = _sanitizePath(path);
    final lsCommand =
        "cd '${_escapeSingleQuotes(sanitizedPath)}' && ls -al --time-style=+%Y-%m-%dT%H:%M:%S";
    final run = await _runSsh(host, lsCommand, timeout: timeout);

    return parseLsOutput(run.stdout);
  }

  @override
  Future<String> homeDirectory(
    SshHost host, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    try {
      final run = await _runSsh(host, 'echo \$HOME', timeout: timeout);
      final output = run.stdout.trim();
      return output.isEmpty ? '/' : output;
    } catch (_) {
      return '/';
    }
  }

  @override
  Future<String> readFile(
    SshHost host,
    String path, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final normalized = _sanitizePath(path);
    final command = [
      '-o',
      'BatchMode=yes',
      '-o',
      'StrictHostKeyChecking=no',
      host.name,
      "cat '${_escapeSingleQuotes(normalized)}'",
    ];
    final run = await _runProcess(
      command,
      timeout: timeout,
      hostForErrors: host,
    );
    return run.stdout;
  }

  @override
  Future<void> writeFile(
    SshHost host,
    String path,
    String contents, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final normalized = _sanitizePath(path);
    final delimiter = _randomDelimiter();
    final encoded = base64.encode(utf8.encode(contents));
    final command = [
      '-o',
      'BatchMode=yes',
      '-o',
      'StrictHostKeyChecking=no',
      host.name,
      "base64 -d > '${_escapeSingleQuotes(normalized)}' <<'$delimiter'\n$encoded\n$delimiter",
    ];

    final run = await _runProcess(
      command,
      timeout: timeout,
      hostForErrors: host,
    );
    final verification = await _verifyPathExists(
      host,
      normalized,
      shouldExist: true,
      timeout: timeout,
    );
    emitDebugEvent(
      host: host,
      operation: 'writeFile',
      command: run.command,
      output: run.stdout,
      verification: verification,
    );
  }

  @override
  Future<void> movePath(
    SshHost host,
    String source,
    String destination, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final normalizedSource = _sanitizePath(source);
    final normalizedDest = _sanitizePath(destination);
    await _ensureRemoteDirectory(host, _dirname(normalizedDest));
    final run = await _runHostCommand(
      host,
      "mv '${_escapeSingleQuotes(normalizedSource)}' '${_escapeSingleQuotes(normalizedDest)}'",
      timeout: timeout,
    );
    final verification = await _verifyPathExists(
      host,
      normalizedDest,
      shouldExist: true,
      timeout: timeout,
    );
    final sourceGone = await _verifyPathExists(
      host,
      normalizedSource,
      shouldExist: false,
      timeout: timeout,
    );
    final combinedVerification =
        verification?.combine(sourceGone) ?? sourceGone;
    emitDebugEvent(
      host: host,
      operation: 'movePath',
      command: run.command,
      output: run.stdout,
      verification: combinedVerification,
    );
  }

  @override
  Future<void> copyPath(
    SshHost host,
    String source,
    String destination, {
    bool recursive = false,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final normalizedSource = _sanitizePath(source);
    final normalizedDest = _sanitizePath(destination);
    await _ensureRemoteDirectory(host, _dirname(normalizedDest));
    final flag = recursive ? '-R ' : '';
    final run = await _runHostCommand(
      host,
      "cp $flag'${_escapeSingleQuotes(normalizedSource)}' '${_escapeSingleQuotes(normalizedDest)}'",
      timeout: timeout,
    );
    final verification = await _verifyPathExists(
      host,
      normalizedDest,
      shouldExist: true,
      timeout: timeout,
    );
    emitDebugEvent(
      host: host,
      operation: 'copyPath',
      command: run.command,
      output: run.stdout,
      verification: verification,
    );
  }

  @override
  Future<void> deletePath(
    SshHost host,
    String path, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final normalized = _sanitizePath(path);
    final run = await _runHostCommand(
      host,
      "rm -rf '${_escapeSingleQuotes(normalized)}'",
      timeout: timeout,
    );
    final verification = await _verifyPathExists(
      host,
      normalized,
      shouldExist: false,
      timeout: timeout,
    );
    emitDebugEvent(
      host: host,
      operation: 'deletePath',
      command: run.command,
      output: run.stdout,
      verification: verification,
    );
  }

  @override
  Future<void> copyBetweenHosts({
    required SshHost sourceHost,
    required String sourcePath,
    required SshHost destinationHost,
    required String destinationPath,
    bool recursive = false,
    Duration timeout = const Duration(minutes: 2),
  }) async {
    final normalizedSource = _sanitizePath(sourcePath);
    final normalizedDest = _sanitizePath(destinationPath);
    await _ensureRemoteDirectory(destinationHost, _dirname(normalizedDest));
    final recursiveFlag = recursive ? '-r ' : '';
    final escapedSource =
        "${sourceHost.name}:${_singleQuoteForShell(normalizedSource)}";
    final escapedDestination =
        "${destinationHost.name}:${_singleQuoteForShell(normalizedDest)}";
    final command =
        "scp -o BatchMode=yes -o StrictHostKeyChecking=no $recursiveFlag$escapedSource $escapedDestination";
    final run = await _runProcess(
      ['bash', '-lc', command],
      timeout: timeout,
      hostForErrors: sourceHost,
    );
    final verification = await _verifyPathExists(
      destinationHost,
      normalizedDest,
      shouldExist: true,
      timeout: timeout,
    );
    emitDebugEvent(
      host: destinationHost,
      operation: 'copyBetweenHosts',
      command: run.command,
      output: run.stdout,
      verification: verification,
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
    final normalizedSource = _sanitizePath(remotePath);
    final destinationDir = Directory(localDestination);
    await destinationDir.create(recursive: true);
    final recursiveFlag = recursive ? '-r ' : '';
    final escapedSource =
        "${host.name}:${_singleQuoteForShell(normalizedSource)}";
    final escapedDestination = _singleQuoteForShell(localDestination);
    final command =
        "scp -o BatchMode=yes -o StrictHostKeyChecking=no $recursiveFlag$escapedSource $escapedDestination";
    await _runProcess(
      ['bash', '-lc', command],
      timeout: timeout,
      hostForErrors: host,
    );
  }

  @override
  Future<void> uploadPath({
    required SshHost host,
    required String localPath,
    required String remoteDestination,
    bool recursive = false,
    Duration timeout = const Duration(minutes: 2),
  }) async {
    final normalizedDest = _sanitizePath(remoteDestination);
    final source =
        FileSystemEntity.typeSync(localPath) == FileSystemEntityType.directory
        ? localPath
        : localPath;
    await _ensureRemoteDirectory(host, _dirname(normalizedDest));
    final recursiveFlag = recursive ? '-r ' : '';
    final escapedSource = _singleQuoteForShell(source);
    final escapedDestination =
        "${host.name}:${_singleQuoteForShell(normalizedDest)}";
    final command =
        "scp -o BatchMode=yes -o StrictHostKeyChecking=no $recursiveFlag$escapedSource $escapedDestination";
    final run = await _runProcess(
      ['bash', '-lc', command],
      timeout: timeout,
      hostForErrors: host,
    );
    final verification = await _verifyPathExists(
      host,
      normalizedDest,
      shouldExist: true,
      timeout: timeout,
    );
    emitDebugEvent(
      host: host,
      operation: 'uploadPath',
      command: run.command,
      output: run.stdout,
      verification: verification,
    );
  }

  Future<RunResult> _runProcess(
    List<String> command, {
    Duration timeout = const Duration(seconds: 10),
    SshHost? hostForErrors,
  }) async {
    final result = await Process.run(
      command.first,
      command.skip(1).toList(),
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
      runInShell: false,
    ).timeout(timeout);

    final stdoutStr = (result.stdout as String?) ?? '';
    final stderrStr = (result.stderr as String?) ?? '';
    if (result.exitCode != 0) {
      // Try to raise a helpful error for SSH invocations.
      if (hostForErrors != null &&
          (command.first.contains('ssh') ||
              command.contains('ssh') ||
              command.first.contains('scp') ||
              command.contains('scp'))) {
        _handleSshError(hostForErrors, result);
      }
      throw Exception(stderrStr.isNotEmpty ? stderrStr : stdoutStr);
    }

    final commandString = command.join(' ');
    return RunResult(
      command: commandString,
      stdout: stdoutStr,
      stderr: stderrStr,
    );
  }

  Future<RunResult> _runSsh(
    SshHost host,
    String command, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final args = [
      '-o',
      'BatchMode=yes',
      '-o',
      'StrictHostKeyChecking=no',
      host.name,
      command,
    ];
    final result = await Process.run(
      'ssh',
      args,
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
      runInShell: false,
    ).timeout(timeout);

    if (result.exitCode != 0) {
      _handleSshError(host, result);
    }

    return RunResult(
      command: 'ssh ${args.join(' ')}',
      stdout: (result.stdout as String?) ?? '',
      stderr: (result.stderr as String?) ?? '',
    );
  }

  String _sanitizePath(String path) {
    if (path.isEmpty) {
      return '/';
    }
    if (path.startsWith('/')) {
      return path;
    }
    return '/$path';
  }

  String _escapeSingleQuotes(String input) => input.replaceAll("'", r"'\''");

  String _singleQuoteForShell(String input) {
    return "'${input.replaceAll("'", "'\\''")}'";
  }

  Future<RunResult> _runHostCommand(
    SshHost host,
    String command, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final result = await _runSsh(host, command, timeout: timeout);
    return result;
  }

  Future<void> _ensureRemoteDirectory(SshHost host, String directory) async {
    if (directory.isEmpty) {
      return;
    }
    await _runHostCommand(host, "mkdir -p '${_escapeSingleQuotes(directory)}'");
  }

  String _dirname(String path) {
    final normalized = _sanitizePath(path);
    final index = normalized.lastIndexOf('/');
    if (index <= 0) {
      return '/';
    }
    return normalized.substring(0, index);
  }

  String _randomDelimiter() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random();
    return List.generate(
      12,
      (index) => chars[rand.nextInt(chars.length)],
    ).join();
  }

  Future<VerificationResult?> _verifyPathExists(
    SshHost host,
    String path, {
    required bool shouldExist,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (!debugMode) {
      return null;
    }
    final command =
        "[ -e '${_escapeSingleQuotes(path)}' ] && echo 'EXISTS' || echo 'MISSING'";
    final run = await _runSsh(host, command, timeout: timeout);
    final exists = run.stdout.trim() == 'EXISTS';
    return VerificationResult(
      command: run.command,
      output: run.stdout,
      passed: shouldExist ? exists : !exists,
    );
  }

}

class RunResult {
  const RunResult({
    required this.command,
    required this.stdout,
    required this.stderr,
  });

  final String command;
  final String stdout;
  final String stderr;
}

class VerificationResult {
  const VerificationResult({
    required this.command,
    required this.output,
    required this.passed,
  });

  final String command;
  final String output;
  final bool passed;

  VerificationResult combine(VerificationResult? other) {
    if (other == null) {
      return this;
    }
    final combinedOutput = [
      output.trim(),
      other.output.trim(),
    ].where((element) => element.isNotEmpty).join('\n');
    return VerificationResult(
      command: '$command && ${other.command}',
      output: combinedOutput,
      passed: passed && other.passed,
    );
  }
}
