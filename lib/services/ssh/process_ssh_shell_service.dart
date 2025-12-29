import 'dart:async';
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
    RunTimeoutHandler? onTimeout,
  }) async {
    final sanitizedPath = sanitizePath(path);
    final lsCommand =
        "cd '${escapeSingleQuotes(sanitizedPath)}' && ls -al --time-style=+%Y-%m-%dT%H:%M:%S";
    final run = await _runner.runSsh(
      host,
      lsCommand,
      timeout: timeout,
      onSshError: _handleSshError,
      onTimeout: onTimeout,
    );

    return parseLsOutput(run.stdout);
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
    void Function(RemoteFileEntry entry)? onEntry,
    RemoteCommandCancellation? cancellation,
    Duration timeout = const Duration(seconds: 30),
    RunTimeoutHandler? onTimeout,
  }) async {
    final effectiveTimeout = searchContents
        ? const Duration(minutes: 2)
        : timeout;
    final sanitizedPath = sanitizePath(basePath);
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
        basePath: sanitizedPath,
        allowDeepNameMatch: false,
      );
      if (include.isNotEmpty) {
        predicates.add('-a \\( $include \\)');
      }
      final exclude = _buildPatternClause(
        excludePattern,
        nameFlag: nameFlag,
        basePath: sanitizedPath,
        allowDeepNameMatch: true,
      );
      if (exclude.isNotEmpty) {
        predicates.add('-a ! \\( $exclude \\)');
      }
      return predicates.join(' ');
    }

    final commandBase = "cd '${escapeSingleQuotes(sanitizedPath)}' &&";
    String dirOutput;
    String fileOutput;
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
        final entry = RemoteFileEntry(
          name: name,
          isDirectory: isDirectory,
          sizeBytes: 0,
          modified: now,
        );
        entries.add(entry);
        onEntry?.call(entry);
      }
    }

    if (searchContents) {
      final grepFlags = <String>[
        '-l',
        if (!matchCase) '-i',
        if (matchWholeWord) '-w',
      ].join(' ');
      final excludePrune = _buildPruneClause(
        excludePattern,
        nameFlag: nameFlag,
        basePath: sanitizedPath,
      );
      final prunePrefix = excludePrune.isEmpty
          ? ''
          : "\\( -type d \\( $excludePrune \\) -prune \\) -o ";
      final filesCommand =
          "$commandBase find . $prunePrefix\\( ${buildPredicate('f', includeName: false)} \\) -exec grep $grepFlags -- '$escapedQuery' {} + 2>/dev/null || true";
      dirOutput = '';
      final filesRun = await _runner.runSshStreaming(
        host,
        filesCommand,
        timeout: effectiveTimeout,
        onSshError: _handleSshError,
        onTimeout: onTimeout,
        cancellation: cancellation,
        onStdoutLine: (line) {
          addEntries(line, isDirectory: false);
        },
      );
      fileOutput = filesRun.stdout;
    } else {
      final printFlag =
          onEntry != null ? "-exec printf '%s\\n' {} \\;" : '-print';
      final dirsCommand =
          "$commandBase find . ${buildPredicate('d', includeName: true)} $printFlag 2>/dev/null || true";
      final filesCommand =
          "$commandBase find . ${buildPredicate('f', includeName: true)} $printFlag 2>/dev/null || true";
      final dirsFuture = _runner.runSshStreaming(
        host,
        dirsCommand,
        timeout: effectiveTimeout,
        onSshError: _handleSshError,
        onTimeout: onTimeout,
        cancellation: cancellation,
        onStdoutLine: (line) {
          addEntries(line, isDirectory: true);
        },
      );
      final filesFuture = _runner.runSshStreaming(
        host,
        filesCommand,
        timeout: effectiveTimeout,
        onSshError: _handleSshError,
        onTimeout: onTimeout,
        cancellation: cancellation,
        onStdoutLine: (line) {
          addEntries(line, isDirectory: false);
        },
      );
      final runs = await Future.wait([dirsFuture, filesFuture]);
      dirOutput = runs[0].stdout;
      fileOutput = runs[1].stdout;
    }
    if (searchContents) {
      addEntries(dirOutput, isDirectory: true);
    }
    return entries;
  }

  @override
  Future<String> homeDirectory(
    SshHost host, {
    Duration timeout = const Duration(seconds: 5),
    RunTimeoutHandler? onTimeout,
  }) async {
    try {
      final run = await _runner.runSsh(
        host,
        'echo \$HOME',
        timeout: timeout,
        onSshError: _handleSshError,
        onTimeout: onTimeout,
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
    RunTimeoutHandler? onTimeout,
  }) async {
    final normalized = sanitizePath(path);
    final run = await _runner.runProcess(
      _runner.buildSshCommand(host, "cat '${escapeSingleQuotes(normalized)}'"),
      timeout: timeout,
      hostForErrors: host,
      onSshError: _handleSshError,
      onTimeout: onTimeout,
    );
    return run.stdout;
  }

  @override
  Future<void> writeFile(
    SshHost host,
    String path,
    String contents, {
    Duration timeout = const Duration(seconds: 15),
    RunTimeoutHandler? onTimeout,
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
      onTimeout: onTimeout,
    );
    final verification = await _verifyPathExists(
      host,
      normalized,
      shouldExist: true,
      timeout: timeout,
      onTimeout: onTimeout,
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
    RunTimeoutHandler? onTimeout,
  }) async {
    final normalizedSource = sanitizePath(source);
    final normalizedDest = sanitizePath(destination);
    await _ensureRemoteDirectory(
      host,
      dirnameFromPath(normalizedDest),
      onTimeout: onTimeout,
    );
    final run = await _runner.runHostCommand(
      host,
      "mv '${escapeSingleQuotes(normalizedSource)}' '${escapeSingleQuotes(normalizedDest)}'",
      timeout: timeout,
      onSshError: _handleSshError,
      onTimeout: onTimeout,
    );
    final verification = await _verifyPathExists(
      host,
      normalizedDest,
      shouldExist: true,
      timeout: timeout,
      onTimeout: onTimeout,
    );
    final sourceGone = await _verifyPathExists(
      host,
      normalizedSource,
      shouldExist: false,
      timeout: timeout,
      onTimeout: onTimeout,
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
    RunTimeoutHandler? onTimeout,
  }) async {
    final normalizedSource = sanitizePath(source);
    final normalizedDest = sanitizePath(destination);
    await _ensureRemoteDirectory(
      host,
      dirnameFromPath(normalizedDest),
      onTimeout: onTimeout,
    );
    final flag = recursive ? '-R ' : '';
    final run = await _runner.runHostCommand(
      host,
      "cp $flag'${escapeSingleQuotes(normalizedSource)}' '${escapeSingleQuotes(normalizedDest)}'",
      timeout: timeout,
      onSshError: _handleSshError,
      onTimeout: onTimeout,
    );
    final verification = await _verifyPathExists(
      host,
      normalizedDest,
      shouldExist: true,
      timeout: timeout,
      onTimeout: onTimeout,
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
    RunTimeoutHandler? onTimeout,
  }) async {
    final normalized = sanitizePath(path);
    final run = await _runner.runHostCommand(
      host,
      "rm -rf '${escapeSingleQuotes(normalized)}'",
      timeout: timeout,
      onSshError: _handleSshError,
      onTimeout: onTimeout,
    );
    final verification = await _verifyPathExists(
      host,
      normalized,
      shouldExist: false,
      timeout: timeout,
      onTimeout: onTimeout,
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
    RunTimeoutHandler? onTimeout,
  }) async {
    final normalizedSource = sanitizePath(sourcePath);
    final normalizedDest = sanitizePath(destinationPath);
    await _ensureRemoteDirectory(
      destinationHost,
      dirnameFromPath(normalizedDest),
      onTimeout: onTimeout,
    );
    final sharedPort = sourceHost.port == destinationHost.port
        ? sourceHost.port
        : null;
    final args =
        _buildScpArgs(
            identityFiles: {
              ...sourceHost.identityFiles,
              ...destinationHost.identityFiles,
            },
            recursive: recursive,
            remotePort: sharedPort,
            extraFlags: const ['-3'],
          )
          ..add(_formatRemoteSpec(sourceHost, normalizedSource))
          ..add(_formatRemoteSpec(destinationHost, normalizedDest));
    final run = await _runner.runProcess(
      args,
      timeout: timeout,
      hostForErrors: sourceHost,
      onSshError: _handleSshError,
      onTimeout: onTimeout,
    );
    final verification = await _verifyPathExists(
      destinationHost,
      normalizedDest,
      shouldExist: true,
      timeout: timeout,
      onTimeout: onTimeout,
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
    void Function(int bytesTransferred)? onBytes,
    RunTimeoutHandler? onTimeout,
  }) async {
    final normalizedSource = sanitizePath(remotePath);
    final destinationDir = Directory(localDestination);
    await destinationDir.create(recursive: true);
    final args =
        _buildScpArgs(
            identityFiles: host.identityFiles.toSet(),
            remotePort: host.port,
            recursive: recursive,
          )
          ..add(_formatRemoteSpec(host, normalizedSource))
          ..add(localDestination);
    await _runner.runProcess(
      args,
      timeout: timeout,
      hostForErrors: host,
      onSshError: _handleSshError,
      onTimeout: onTimeout,
    );
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
    final normalizedDest = sanitizePath(remoteDestination);
    final source = localPath;
    await _ensureRemoteDirectory(
      host,
      dirnameFromPath(normalizedDest),
      onTimeout: onTimeout,
    );
    final args =
        _buildScpArgs(
            identityFiles: host.identityFiles.toSet(),
            remotePort: host.port,
            recursive: recursive,
          )
          ..add(source)
          ..add(_formatRemoteSpec(host, normalizedDest));
    final run = await _runner.runProcess(
      args,
      timeout: timeout,
      hostForErrors: host,
      onSshError: _handleSshError,
      onTimeout: onTimeout,
    );
    final verification = await _verifyPathExists(
      host,
      normalizedDest,
      shouldExist: true,
      timeout: timeout,
      onTimeout: onTimeout,
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
    RunTimeoutHandler? onTimeout,
  }) async {
    _logProcess('Running command on ${host.name}: $command');
    final run = await _runner.runSsh(
      host,
      command,
      timeout: timeout,
      onSshError: _handleSshError,
      onTimeout: onTimeout,
    );
    _logProcess(
      'Command on ${host.name} completed. Output length=${run.stdout.length}',
    );
    return run.stdout;
  }

  @override
  Future<String> runCommandStreaming(
    SshHost host,
    String command, {
    Duration timeout = const Duration(seconds: 10),
    RunTimeoutHandler? onTimeout,
    RemoteCommandCancellation? cancellation,
    void Function(String line)? onStdoutLine,
    void Function(String line)? onStderrLine,
  }) async {
    _logProcess('Running command on ${host.name}: $command');
    final run = await _runner.runSshStreaming(
      host,
      command,
      timeout: timeout,
      onSshError: _handleSshError,
      onTimeout: onTimeout,
      cancellation: cancellation,
      onStdoutLine: onStdoutLine,
      onStderrLine: onStderrLine,
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
    try {
      final env = _sessionEnvironment();
      LocalPtySession session;
      if (Platform.isWindows) {
        final sshArgs = _runner.buildSshArgumentsForTerminal(host).join(' ');
        final commandLine = 'ssh $sshArgs';
        AppLogger.d(
          'Starting system SSH via cmd.exe /c "$commandLine"',
          tag: 'ProcessSSH',
        );
        session = LocalPtySession(
          executable: 'cmd.exe',
          arguments: ['/c', commandLine],
          environment: env,
          cols: columns,
          rows: rows,
        );
      } else {
        final args = _runner.buildSshArgumentsForTerminal(host);
        AppLogger.d(
          'Starting system SSH via ssh ${args.join(' ')}',
          tag: 'ProcessSSH',
        );
        session = LocalPtySession(
          executable: 'ssh',
          arguments: args,
          environment: env,
          cols: columns,
          rows: rows,
        );
      }
      unawaited(
        session.exitCode.then(
          (code) => AppLogger.d(
            'System SSH session for ${host.name} exited with code $code',
            tag: 'ProcessSSH',
          ),
        ),
      );
      return session;
    } catch (error, stack) {
      AppLogger.w(
        'Failed to start system SSH session for ${host.name}: $error',
        tag: 'ProcessSSH',
        error: error,
        stackTrace: stack,
      );
      rethrow;
    }
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
            trimmed.contains('*') ||
            trimmed.contains('?') ||
            trimmed.contains('[');
        if (hasGlob) {
          clauses.add("-path '${escapeSingleQuotes(trimmed)}'");
        } else if (hadTrailingSlash) {
          clauses.add("-path '${escapeSingleQuotes('$trimmed/*')}'");
        } else {
          clauses.add("-path '${escapeSingleQuotes(trimmed)}'");
          clauses.add("-path '${escapeSingleQuotes('$trimmed/*')}'");
        }
      } else {
        final escaped = escapeSingleQuotes(normalizedPattern);
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
            trimmed.contains('*') ||
            trimmed.contains('?') ||
            trimmed.contains('[');
        if (hasGlob) {
          clauses.add("-path '${escapeSingleQuotes(trimmed)}'");
        } else {
          clauses.add("-path '${escapeSingleQuotes(trimmed)}'");
          clauses.add("-path '${escapeSingleQuotes('$trimmed/*')}'");
        }
      } else {
        final escaped = escapeSingleQuotes(normalizedPattern);
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
      normalized = '.$normalized';
    }
    return normalized;
  }

  Map<String, String> _sessionEnvironment() {
    final env = Map<String, String>.from(Platform.environment);
    env.putIfAbsent('TERM', () => 'xterm-256color');
    if (Platform.isWindows) {
      env.putIfAbsent('SSH_AUTH_SOCK', () => r'\\.\pipe\openssh-ssh-agent');
    }
    return env;
  }

  List<String> _buildScpArgs({
    required Set<String> identityFiles,
    int? remotePort,
    bool recursive = false,
    List<String> extraFlags = const [],
  }) {
    final args = <String>[
      'scp',
      '-o',
      'BatchMode=yes',
      '-o',
      'StrictHostKeyChecking=accept-new',
      ...extraFlags,
    ];
    if (remotePort != null) {
      args.addAll(['-P', remotePort.toString()]);
    }
    if (recursive) {
      args.add('-r');
    }
    for (final identity in identityFiles) {
      final trimmed = identity.trim();
      if (trimmed.isNotEmpty) {
        args.addAll(['-i', trimmed]);
      }
    }
    return args;
  }

  String _formatRemoteSpec(SshHost host, String path) {
    final normalized = sanitizePath(path);
    // scp remote specs accept raw paths; quoting here can be interpreted
    // as a literal character by some servers, so keep it unquoted.
    return '${_runner.connectionTarget(host)}:$normalized';
  }

  Future<void> _ensureRemoteDirectory(
    SshHost host,
    String directory, {
    RunTimeoutHandler? onTimeout,
  }) async {
    if (directory.isEmpty) {
      return;
    }
    await _runner.runHostCommand(
      host,
      "mkdir -p '${escapeSingleQuotes(directory)}'",
      onSshError: _handleSshError,
      onTimeout: onTimeout,
    );
  }

  Future<VerificationResult?> _verifyPathExists(
    SshHost host,
    String path, {
    required bool shouldExist,
    Duration timeout = const Duration(seconds: 5),
    RunTimeoutHandler? onTimeout,
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
      onTimeout: onTimeout,
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
