import 'dart:convert';
import 'dart:io';

import '../../models/remote_file_entry.dart';
import '../../models/ssh_host.dart';
import '../logging/app_logger.dart';
import 'remote_shell_base.dart';
import 'terminal_session.dart';
import 'process_ssh_runner.dart';

class ProcessRemoteShellService extends RemoteShellService {
  const ProcessRemoteShellService({super.debugMode = false, super.observer});

  final ProcessSshRunner _runner = const ProcessSshRunner();

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
      throw Exception(
        'SSH authentication failed for ${host.name}: $errorMessage',
      );
    }

    throw Exception(errorMessage);
  }

  @override
  Future<List<RemoteFileEntry>> listDirectory(
    SshHost host,
    String path, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final sanitizedPath = sanitizePath(path);
    final lsCommand =
        "cd '${escapeSingleQuotes(sanitizedPath)}' && ls -al --time-style=+%Y-%m-%dT%H:%M:%S";
    final run = await _runner.runSsh(
      host,
      lsCommand,
      timeout: timeout,
      onSshError: _handleSshError,
    );

    return parseLsOutput(run.stdout);
  }

  @override
  Future<String> homeDirectory(
    SshHost host, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    try {
      final run = await _runner.runSsh(
        host,
        'echo \$HOME',
        timeout: timeout,
        onSshError: _handleSshError,
      );
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
    final normalized = sanitizePath(path);
    final run = await _runner.runProcess(
      _runner.buildSshCommand(
        host,
        "cat '${escapeSingleQuotes(normalized)}'",
      ),
      timeout: timeout,
      hostForErrors: host,
      onSshError: _handleSshError,
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
    final normalized = sanitizePath(path);
    final delimiter = randomDelimiter();
    final encoded = base64.encode(utf8.encode(contents));
    final run = await _runner.runProcess(
      _runner.buildSshCommand(
        host,
        "base64 -d > '${escapeSingleQuotes(normalized)}' <<'$delimiter'\n$encoded\n$delimiter",
      ),
      timeout: timeout,
      hostForErrors: host,
      onSshError: _handleSshError,
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
    final normalizedSource = sanitizePath(source);
    final normalizedDest = sanitizePath(destination);
    await _ensureRemoteDirectory(host, dirnameFromPath(normalizedDest));
    final run = await _runner.runHostCommand(
      host,
      "mv '${escapeSingleQuotes(normalizedSource)}' '${escapeSingleQuotes(normalizedDest)}'",
      timeout: timeout,
      onSshError: _handleSshError,
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
    final normalizedSource = sanitizePath(source);
    final normalizedDest = sanitizePath(destination);
    await _ensureRemoteDirectory(host, dirnameFromPath(normalizedDest));
    final flag = recursive ? '-R ' : '';
    final run = await _runner.runHostCommand(
      host,
      "cp $flag'${escapeSingleQuotes(normalizedSource)}' '${escapeSingleQuotes(normalizedDest)}'",
      timeout: timeout,
      onSshError: _handleSshError,
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
    final normalized = sanitizePath(path);
    final run = await _runner.runHostCommand(
      host,
      "rm -rf '${escapeSingleQuotes(normalized)}'",
      timeout: timeout,
      onSshError: _handleSshError,
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
    final normalizedSource = sanitizePath(sourcePath);
    final normalizedDest = sanitizePath(destinationPath);
    await _ensureRemoteDirectory(destinationHost, dirnameFromPath(normalizedDest));
    final recursiveFlag = recursive ? '-r ' : '';
    final escapedSource =
        "${sourceHost.name}:${singleQuoteForShell(normalizedSource)}";
    final escapedDestination =
        "${destinationHost.name}:${singleQuoteForShell(normalizedDest)}";
    final command =
        "scp -o BatchMode=yes -o StrictHostKeyChecking=no $recursiveFlag$escapedSource $escapedDestination";
    final run = await _runner.runProcess(
      ['bash', '-lc', command],
      timeout: timeout,
      hostForErrors: sourceHost,
      onSshError: _handleSshError,
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
    final normalizedSource = sanitizePath(remotePath);
    final destinationDir = Directory(localDestination);
    await destinationDir.create(recursive: true);
    final recursiveFlag = recursive ? '-r ' : '';
    final escapedSource =
        "${host.name}:${singleQuoteForShell(normalizedSource)}";
    final escapedDestination = singleQuoteForShell(localDestination);
    final command =
        "scp -o BatchMode=yes -o StrictHostKeyChecking=no $recursiveFlag$escapedSource $escapedDestination";
    await _runner.runProcess(
      ['bash', '-lc', command],
      timeout: timeout,
      hostForErrors: host,
      onSshError: _handleSshError,
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
    final normalizedDest = sanitizePath(remoteDestination);
    final source =
        FileSystemEntity.typeSync(localPath) == FileSystemEntityType.directory
        ? localPath
        : localPath;
    await _ensureRemoteDirectory(host, dirnameFromPath(normalizedDest));
    final recursiveFlag = recursive ? '-r ' : '';
    final escapedSource = singleQuoteForShell(source);
    final escapedDestination =
        "${host.name}:${singleQuoteForShell(normalizedDest)}";
    final command =
        "scp -o BatchMode=yes -o StrictHostKeyChecking=no $recursiveFlag$escapedSource $escapedDestination";
    final run = await _runner.runProcess(
      ['bash', '-lc', command],
      timeout: timeout,
      hostForErrors: host,
      onSshError: _handleSshError,
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

  @override
  Future<String> runCommand(
    SshHost host,
    String command, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    _logProcess('Running command on ${host.name}: $command');
    final run = await _runner.runSsh(
      host,
      command,
      timeout: timeout,
      onSshError: _handleSshError,
    );
    _logProcess(
      'Command on ${host.name} completed. Output length=${run.stdout.length}',
    );
    return run.stdout;
  }

  @override
  Future<TerminalSession> createTerminalSession(
    SshHost host, {
    required TerminalSessionOptions options,
  }) async {
    final columns = options.columns > 0 ? options.columns : 80;
    final rows = options.rows > 0 ? options.rows : 25;
    return LocalPtySession(
      executable: 'ssh',
      arguments: _runner.buildSshArgumentsForTerminal(host),
      cols: columns,
      rows: rows,
    );
  }

  Future<void> _ensureRemoteDirectory(SshHost host, String directory) async {
    if (directory.isEmpty) {
      return;
    }
    await _runner.runHostCommand(
      host,
      "mkdir -p '${escapeSingleQuotes(directory)}'",
      onSshError: _handleSshError,
    );
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
        "[ -e '${escapeSingleQuotes(path)}' ] && echo 'EXISTS' || echo 'MISSING'";
    final run = await _runner.runSsh(
      host,
      command,
      timeout: timeout,
      onSshError: _handleSshError,
    );
    final exists = run.stdout.trim() == 'EXISTS';
    return VerificationResult(
      command: run.command,
      output: run.stdout,
      passed: shouldExist ? exists : !exists,
    );
  }
}

void _logProcess(String message) {
  AppLogger.d(message, tag: 'ProcessSSH');
}
