import 'dart:convert';
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
    RunTimeoutHandler? onTimeout,
  }) async {
    final output = await runCommand(
      host,
      'ls -la --time-style=+%Y-%m-%dT%H:%M:%S ${_escape(path)}',
      timeout: timeout,
      onTimeout: onTimeout,
    );
    return parseLsOutput(output);
  }

  @override
  Future<List<RemoteFileEntry>> searchPaths(
    SshHost host,
    String basePath,
    String query, {
    String? includePattern,
    String? excludePattern,
    bool matchCase = false,
    bool matchWholeWord = false,
    bool searchContents = false,
    Duration timeout = const Duration(seconds: 15),
    RunTimeoutHandler? onTimeout,
  }) async {
    final effectiveTimeout =
        searchContents ? const Duration(minutes: 2) : timeout;
    final sanitized = sanitizePath(basePath);
    final escapedQuery = escapeSingleQuotes(query.trim());
    final pattern = escapedQuery.isEmpty
        ? '*'
        : (matchWholeWord ? escapedQuery : '*$escapedQuery*');
    final nameFlag = matchCase ? '-name' : '-iname';
    String buildPredicate(String typeFlag, {required bool includeName}) {
      final predicates = <String>['-type $typeFlag'];
      if (includeName) {
        predicates.add("$nameFlag '$pattern'");
      }
      final include = _buildPatternClause(
        includePattern,
        nameFlag: nameFlag,
        basePath: sanitized,
        allowDeepNameMatch: false,
      );
      if (include.isNotEmpty) {
        predicates.add('-a \\( $include \\)');
      }
      final exclude = _buildPatternClause(
        excludePattern,
        nameFlag: nameFlag,
        basePath: sanitized,
        allowDeepNameMatch: true,
      );
      if (exclude.isNotEmpty) {
        predicates.add('-a ! \\( $exclude \\)');
      }
      return predicates.join(' ');
    }
    final commandBase = "cd '${escapeSingleQuotes(sanitized)}' &&";
    String dirOutput;
    String fileOutput;
    if (searchContents) {
      final grepFlags = <String>[
        '-l',
        if (!matchCase) '-i',
        if (matchWholeWord) '-w',
      ].join(' ');
      final excludePrune = _buildPruneClause(
        excludePattern,
        nameFlag: nameFlag,
        basePath: sanitized,
      );
      final prunePrefix = excludePrune.isEmpty
          ? ''
          : "\\( -type d \\( $excludePrune \\) -prune \\) -o ";
      final filesCommand =
          "$commandBase find . $prunePrefix\\( ${buildPredicate('f', includeName: false)} \\) -exec grep $grepFlags -- '$escapedQuery' {} + 2>/dev/null || true";
      dirOutput = '';
      fileOutput = await runCommand(
        host,
        filesCommand,
        timeout: effectiveTimeout,
        onTimeout: onTimeout,
      );
    } else {
      final dirsCommand =
          "$commandBase find . ${buildPredicate('d', includeName: true)} -print 2>/dev/null || true";
      final filesCommand =
          "$commandBase find . ${buildPredicate('f', includeName: true)} -print 2>/dev/null || true";
      dirOutput = await runCommand(
        host,
        dirsCommand,
        timeout: effectiveTimeout,
        onTimeout: onTimeout,
      );
      fileOutput = await runCommand(
        host,
        filesCommand,
        timeout: effectiveTimeout,
        onTimeout: onTimeout,
      );
    }
    final entries = <RemoteFileEntry>[];
    final now = DateTime.now();
    void addEntries(String output, {required bool isDirectory}) {
      for (final line in const LineSplitter().convert(output)) {
        if (line.isEmpty || line == '.' || line == './') {
          continue;
        }
        final name = line.startsWith('./') ? line.substring(2) : line;
        if (name.isEmpty) {
          continue;
        }
        entries.add(
          RemoteFileEntry(
            name: name,
            isDirectory: isDirectory,
            sizeBytes: 0,
            modified: now,
          ),
        );
      }
    }
    addEntries(dirOutput, isDirectory: true);
    addEntries(fileOutput, isDirectory: false);
    return entries;
  }

  @override
  Future<String> homeDirectory(
    SshHost host, {
    Duration timeout = const Duration(seconds: 5),
    RunTimeoutHandler? onTimeout,
  }) async {
    final output = await runCommand(
      host,
      r'printf %s "$HOME"',
      timeout: timeout,
      onTimeout: onTimeout,
    );
    return output.trim().isEmpty ? '/' : output.trim();
  }

  @override
  Future<String> readFile(
    SshHost host,
    String path, {
    Duration timeout = const Duration(seconds: 15),
    RunTimeoutHandler? onTimeout,
  }) {
    return runCommand(
      host,
      'cat ${_escape(path)}',
      timeout: timeout,
      onTimeout: onTimeout,
    );
  }

  @override
  Future<void> writeFile(
    SshHost host,
    String path,
    String contents, {
    Duration timeout = const Duration(seconds: 15),
    RunTimeoutHandler? onTimeout,
  }) async {
    final tempDir = await _makeTempDir(timeout: timeout);
    try {
      final tempFile = p.join(tempDir, p.basename(path));
      await baseShell.writeFile(
        this.host,
        tempFile,
        contents,
        timeout: timeout,
        onTimeout: onTimeout,
      );
      await baseShell.runCommand(
        this.host,
        'docker cp ${_escapeLocal(tempFile)} $containerId:${_escape(path)}',
        timeout: timeout,
        onTimeout: onTimeout,
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
    RunTimeoutHandler? onTimeout,
  }) {
    return runCommand(
      host,
      'mv ${_escape(source)} ${_escape(destination)}',
      timeout: timeout,
      onTimeout: onTimeout,
    );
  }

  @override
  Future<void> copyPath(
    SshHost host,
    String source,
    String destination, {
    bool recursive = false,
    Duration timeout = const Duration(seconds: 20),
    RunTimeoutHandler? onTimeout,
  }) {
    final flag = recursive ? '-r' : '';
    return runCommand(
      host,
      'cp $flag ${_escape(source)} ${_escape(destination)}',
      timeout: timeout,
      onTimeout: onTimeout,
    );
  }

  @override
  Future<void> deletePath(
    SshHost host,
    String path, {
    Duration timeout = const Duration(seconds: 15),
    RunTimeoutHandler? onTimeout,
  }) {
    return runCommand(
      host,
      'rm -rf ${_escape(path)}',
      timeout: timeout,
      onTimeout: onTimeout,
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
    RunTimeoutHandler? onTimeout,
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
    void Function(int bytesTransferred)? onBytes,
    RunTimeoutHandler? onTimeout,
  }) async {
    final tempDir = await _makeTempDir(timeout: timeout);
    try {
      await baseShell.runCommand(
        this.host,
        'docker cp $containerId:${_escape(remotePath)} ${_escapeLocal(tempDir)}',
        timeout: timeout,
        onTimeout: onTimeout,
      );
      final payload = p.join(tempDir, p.basename(remotePath));
      await baseShell.downloadPath(
        host: this.host,
        remotePath: payload,
        localDestination: localDestination,
        recursive: recursive,
        timeout: timeout,
        onBytes: onBytes,
        onTimeout: onTimeout,
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
    void Function(int bytesTransferred)? onBytes,
    RunTimeoutHandler? onTimeout,
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
        onBytes: onBytes,
        onTimeout: onTimeout,
      );
      await baseShell.runCommand(
        this.host,
        'docker cp ${_escapeLocal(tempDest)} $containerId:${_escape(remoteDestination)}',
        timeout: timeout,
        onTimeout: onTimeout,
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
    RunTimeoutHandler? onTimeout,
  }) async {
    final wrapped =
        'docker exec $containerId sh -lc ${_escapeSingleCommand(command)}';
    return baseShell.runCommand(
      this.host,
      wrapped,
      timeout: timeout,
      onTimeout: onTimeout,
    );
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
    RunTimeoutHandler? onTimeout,
  }) async {
    final output = await runCommand(
      host,
      'ls -la --time-style=+%Y-%m-%dT%H:%M:%S ${_escape(path)}',
      timeout: timeout,
    );
    return parseLsOutput(output);
  }

  @override
  Future<List<RemoteFileEntry>> searchPaths(
    SshHost host,
    String basePath,
    String query, {
    String? includePattern,
    String? excludePattern,
    bool matchCase = false,
    bool matchWholeWord = false,
    bool searchContents = false,
    Duration timeout = const Duration(seconds: 15),
    RunTimeoutHandler? onTimeout,
  }) async {
    final effectiveTimeout =
        searchContents ? const Duration(minutes: 2) : timeout;
    final sanitized = sanitizePath(basePath);
    final escapedQuery = escapeSingleQuotes(query.trim());
    final pattern = escapedQuery.isEmpty
        ? '*'
        : (matchWholeWord ? escapedQuery : '*$escapedQuery*');
    final nameFlag = matchCase ? '-name' : '-iname';
    String buildPredicate(String typeFlag, {required bool includeName}) {
      final predicates = <String>['-type $typeFlag'];
      if (includeName) {
        predicates.add("$nameFlag '$pattern'");
      }
      final include = _buildPatternClause(
        includePattern,
        nameFlag: nameFlag,
        basePath: sanitized,
        allowDeepNameMatch: false,
      );
      if (include.isNotEmpty) {
        predicates.add('-a \\( $include \\)');
      }
      final exclude = _buildPatternClause(
        excludePattern,
        nameFlag: nameFlag,
        basePath: sanitized,
        allowDeepNameMatch: true,
      );
      if (exclude.isNotEmpty) {
        predicates.add('-a ! \\( $exclude \\)');
      }
      return predicates.join(' ');
    }
    final commandBase = "cd '${escapeSingleQuotes(sanitized)}' &&";
    String dirOutput;
    String fileOutput;
    if (searchContents) {
      final grepFlags = <String>[
        '-l',
        if (!matchCase) '-i',
        if (matchWholeWord) '-w',
      ].join(' ');
      final excludePrune = _buildPruneClause(
        excludePattern,
        nameFlag: nameFlag,
        basePath: sanitized,
      );
      final prunePrefix = excludePrune.isEmpty
          ? ''
          : "\\( -type d \\( $excludePrune \\) -prune \\) -o ";
      final filesCommand =
          "$commandBase find . $prunePrefix\\( ${buildPredicate('f', includeName: false)} \\) -exec grep $grepFlags -- '$escapedQuery' {} + 2>/dev/null || true";
      dirOutput = '';
      fileOutput = await runCommand(host, filesCommand, timeout: effectiveTimeout);
    } else {
      final dirsCommand =
          "$commandBase find . ${buildPredicate('d', includeName: true)} -print 2>/dev/null || true";
      final filesCommand =
          "$commandBase find . ${buildPredicate('f', includeName: true)} -print 2>/dev/null || true";
      dirOutput = await runCommand(host, dirsCommand, timeout: effectiveTimeout);
      fileOutput = await runCommand(host, filesCommand, timeout: effectiveTimeout);
    }
    final entries = <RemoteFileEntry>[];
    final now = DateTime.now();
    void addEntries(String output, {required bool isDirectory}) {
      for (final line in const LineSplitter().convert(output)) {
        if (line.isEmpty || line == '.' || line == './') {
          continue;
        }
        final name = line.startsWith('./') ? line.substring(2) : line;
        if (name.isEmpty) {
          continue;
        }
        entries.add(
          RemoteFileEntry(
            name: name,
            isDirectory: isDirectory,
            sizeBytes: 0,
            modified: now,
          ),
        );
      }
    }
    addEntries(dirOutput, isDirectory: true);
    addEntries(fileOutput, isDirectory: false);
    return entries;
  }

  @override
  Future<String> homeDirectory(
    SshHost host, {
    Duration timeout = const Duration(seconds: 5),
    RunTimeoutHandler? onTimeout,
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
    RunTimeoutHandler? onTimeout,
  }) {
    return runCommand(host, 'cat ${_escape(path)}', timeout: timeout);
  }

  @override
  Future<void> writeFile(
    SshHost host,
    String path,
    String contents, {
    Duration timeout = const Duration(seconds: 15),
    RunTimeoutHandler? onTimeout,
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
    RunTimeoutHandler? onTimeout,
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
    RunTimeoutHandler? onTimeout,
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
    RunTimeoutHandler? onTimeout,
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
    RunTimeoutHandler? onTimeout,
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
    void Function(int bytesTransferred)? onBytes,
    RunTimeoutHandler? onTimeout,
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
    void Function(int bytesTransferred)? onBytes,
    RunTimeoutHandler? onTimeout,
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
    RunTimeoutHandler? onTimeout,
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

String _buildPatternClause(
  String? rawPatterns, {
  required String nameFlag,
  required String basePath,
  required bool allowDeepNameMatch,
}) {
  final patterns = rawPatterns
      ?.split(',')
      .map((pattern) => pattern.trim())
      .where((pattern) => pattern.isNotEmpty)
      .toList();
  if (patterns == null || patterns.isEmpty) {
    return '';
  }
  final clauses = <String>[];
  for (final pattern in patterns) {
    final normalizedPattern = _normalizePathPattern(pattern, basePath);
    if (normalizedPattern.contains('/')) {
      final normalized = normalizedPattern;
      final hadTrailingSlash = normalized.endsWith('/');
      final trimmed = hadTrailingSlash
          ? normalized.substring(0, normalized.length - 1)
          : normalized;
      final hasGlob =
          trimmed.contains('*') || trimmed.contains('?') || trimmed.contains('[');
      if (hasGlob) {
        clauses.add("-path '${trimmed.replaceAll("'", r"'\''")}'");
      } else if (hadTrailingSlash) {
        clauses.add("-path '${'$trimmed/*'.replaceAll("'", r"'\''")}'");
      } else {
        clauses.add("-path '${trimmed.replaceAll("'", r"'\''")}'");
        clauses.add("-path '${'$trimmed/*'.replaceAll("'", r"'\''")}'");
      }
    } else {
      final escaped = normalizedPattern.replaceAll("'", r"'\''");
      if (allowDeepNameMatch) {
        clauses.add("$nameFlag '$escaped'");
        clauses.add("-path './$escaped'");
        clauses.add("-path './$escaped/*'");
        clauses.add("-path './*/$escaped/*'");
      } else {
        clauses.add("-path './$escaped'");
        clauses.add("-path './$escaped/*'");
      }
    }
  }
  return clauses.join(' -o ');
}

String _buildPruneClause(
  String? rawPatterns, {
  required String nameFlag,
  required String basePath,
}) {
  final patterns = rawPatterns
      ?.split(',')
      .map((pattern) => pattern.trim())
      .where((pattern) => pattern.isNotEmpty)
      .toList();
  if (patterns == null || patterns.isEmpty) {
    return '';
  }
  final clauses = <String>[];
  for (final pattern in patterns) {
    final normalizedPattern = _normalizePathPattern(pattern, basePath);
    if (normalizedPattern.contains('/')) {
      final normalized = normalizedPattern;
      final trimmed = normalized.endsWith('/')
          ? normalized.substring(0, normalized.length - 1)
          : normalized;
      final hasGlob =
          trimmed.contains('*') || trimmed.contains('?') || trimmed.contains('[');
      if (hasGlob) {
        clauses.add("-path '${trimmed.replaceAll("'", r"'\''")}'");
      } else {
        clauses.add("-path '${trimmed.replaceAll("'", r"'\''")}'");
        clauses.add("-path '${'$trimmed/*'.replaceAll("'", r"'\''")}'");
      }
    } else {
      final escaped = normalizedPattern.replaceAll("'", r"'\''");
      clauses.add("$nameFlag '$escaped'");
    }
  }
  return clauses.join(' -o ');
}

String _normalizePathPattern(String pattern, String basePath) {
  var normalized = pattern.trim();
  if (!normalized.contains('/')) {
    return normalized;
  }
  if (normalized.startsWith(basePath)) {
    normalized = normalized.substring(basePath.length);
  }
  if (normalized.startsWith('/')) {
    normalized = normalized.substring(1);
  }
  if (normalized.isEmpty) {
    return '.';
  }
  if (!normalized.startsWith('./') &&
      !normalized.startsWith('/') &&
      normalized.contains('/')) {
    normalized = './$normalized';
  } else if (normalized.contains('/') && normalized.startsWith('/')) {
    normalized = '.${normalized}';
  }
  return normalized;
}
