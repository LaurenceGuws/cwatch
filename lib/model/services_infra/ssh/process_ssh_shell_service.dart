import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cwatch/model/models/remote_file_entry.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import '../logging/app_logger.dart';
import 'process_ssh_file_operation_planner.dart';
import 'process_ssh_search_planner.dart';
import 'process_ssh_run_result_handler.dart';
import 'process_ssh_failure_mapper.dart';
import 'remote_shell_base.dart';
import 'terminal_session.dart';
import 'process_ssh_runner.dart';

class ProcessRemoteShellService extends RemoteShellService {
  const ProcessRemoteShellService({super.debugMode = false, super.observer});

  final ProcessSshRunner _runner = const ProcessSshRunner();
  final ProcessSshFailureMapper _failureMapper = const ProcessSshFailureMapper();
  final ProcessSshRunResultHandler _resultHandler =
      const ProcessSshRunResultHandler();
  final ProcessSshFileOperationPlanner _filePlanner =
      const ProcessSshFileOperationPlanner();
  final ProcessSshSearchPlanner _searchPlanner =
      const ProcessSshSearchPlanner();

  /// Handles SSH command errors, detecting authentication failures.
  Never _handleSshError(SshHost host, ProcessResult result) {
    throw _failureMapper.fromProcessResult(host, result);
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
    try {
      final run = await _runSsh(
        host,
        lsCommand,
        timeout: timeout,
        onTimeout: onTimeout,
      );
      _resultHandler.emitOutput(
        shell: this,
        host: host,
        operation: 'listDirectory',
        run: run,
        trimOutput: true,
      );
      return parseLsOutput(run.stdout);
    } catch (error) {
      AppLogger.remote(tag: 'SSH', source: 'ssh', host: host).warn(
        'listDirectory failed',
        error: error,
        remote: RemoteCommandDetails(
          operation: 'listDirectory',
          command: lsCommand,
          output: 'Error: $error',
          contextLabel: host.name,
        ),
      );
      rethrow;
    }
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
    final plan = _searchPlanner.createPlan(
      basePath: basePath,
      query: query,
      matchCase: matchCase,
      searchContents: searchContents,
      timeout: timeout,
    );
    final effectiveTimeout =
        Duration(seconds: plan.effectiveTimeoutSeconds);
    String dirOutput;
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
      final excludePrune = _searchPlanner.buildPruneClause(
        excludePattern,
        nameFlag: plan.nameFlag,
        basePath: plan.basePath,
      );
      final prunePrefix = excludePrune.isEmpty
          ? ''
          : "\\( -type d \\( $excludePrune \\) -prune \\) -o ";
      final filesCommand =
          "${plan.commandBase} find . $prunePrefix\\( ${_searchPlanner.buildPredicate(typeFlag: 'f', includeName: false, plan: plan, matchWholeWord: matchWholeWord, includePattern: includePattern, excludePattern: excludePattern)} \\) -exec grep $grepFlags -- '${plan.escapedQuery}' {} + 2>/dev/null || true";
      dirOutput = '';
      await _runSshStreaming(
        host,
        filesCommand,
        timeout: effectiveTimeout,
        onTimeout: onTimeout,
        cancellation: cancellation,
        onStdoutLine: (line) {
          addEntries(line, isDirectory: false);
        },
      );
    } else {
      final printFlag = onEntry != null
          ? "-exec printf '%s\\n' {} \\;"
          : '-print';
      final dirsCommand =
          "${plan.commandBase} find . ${_searchPlanner.buildPredicate(typeFlag: 'd', includeName: true, plan: plan, matchWholeWord: matchWholeWord, includePattern: includePattern, excludePattern: excludePattern)} $printFlag 2>/dev/null || true";
      final filesCommand =
          "${plan.commandBase} find . ${_searchPlanner.buildPredicate(typeFlag: 'f', includeName: true, plan: plan, matchWholeWord: matchWholeWord, includePattern: includePattern, excludePattern: excludePattern)} $printFlag 2>/dev/null || true";
      final dirsFuture = _runSshStreaming(
        host,
        dirsCommand,
        timeout: effectiveTimeout,
        onTimeout: onTimeout,
        cancellation: cancellation,
        onStdoutLine: (line) {
          addEntries(line, isDirectory: true);
        },
      );
      final filesFuture = _runSshStreaming(
        host,
        filesCommand,
        timeout: effectiveTimeout,
        onTimeout: onTimeout,
        cancellation: cancellation,
        onStdoutLine: (line) {
          addEntries(line, isDirectory: false);
        },
      );
      final runs = await Future.wait([dirsFuture, filesFuture]);
      dirOutput = runs[0].stdout;
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
      final run = await _runSsh(
        host,
        'echo \$HOME',
        timeout: timeout,
        onTimeout: onTimeout,
      );
      final output = _resultHandler.emitOutput(
        shell: this,
        host: host,
        operation: 'homeDirectory',
        run: run,
        trimOutput: true,
      );
      return output.isEmpty ? '/' : output;
    } catch (error, stackTrace) {
      AppLogger.remote(tag: 'SSH', source: 'ssh', host: host).warn(
        'homeDirectory failed',
        error: error,
        remote: RemoteCommandDetails(
          operation: 'homeDirectory',
          command: 'echo \$HOME',
          output: 'Error: $error',
          contextLabel: host.name,
        ),
      );
      AppLogger().warn(
        'Failed to resolve home directory for ${host.name}',
        tag: 'ProcessSSH',
        error: error,
        stackTrace: stackTrace,
      );
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
    final normalized = _filePlanner.normalize(path);
    final run = await _runProcess(
      host,
      _runner.buildSshCommand(host, _filePlanner.readFileCommand(normalized)),
      timeout: timeout,
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
    final normalized = _filePlanner.normalize(path);
    final delimiter = randomDelimiter();
    final encoded = base64.encode(utf8.encode(contents));
    final run = await _runProcess(
      host,
      _runner.buildSshCommand(
        host,
        _filePlanner.writeFileCommand(
          path: normalized,
          encodedContents: encoded,
          delimiter: delimiter,
        ),
      ),
      timeout: timeout,
      onTimeout: onTimeout,
    );
    final verification = await _verifyPathExists(
      host,
      normalized,
      shouldExist: true,
      timeout: timeout,
      onTimeout: onTimeout,
    );
    _resultHandler.emitOutput(
      shell: this,
      host: host,
      operation: 'writeFile',
      run: run,
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
    final normalizedSource = _filePlanner.normalize(source);
    final normalizedDest = _filePlanner.normalize(destination);
    await _ensureRemoteDirectory(
      host,
      _filePlanner.parentDirectory(normalizedDest),
      onTimeout: onTimeout,
    );
    final run = await _runHostCommand(
      host,
      _filePlanner.movePathCommand(normalizedSource, normalizedDest),
      timeout: timeout,
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
    _resultHandler.emitOutput(
      shell: this,
      host: host,
      operation: 'movePath',
      run: run,
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
    final normalizedSource = _filePlanner.normalize(source);
    final normalizedDest = _filePlanner.normalize(destination);
    await _ensureRemoteDirectory(
      host,
      _filePlanner.parentDirectory(normalizedDest),
      onTimeout: onTimeout,
    );
    final run = await _runHostCommand(
      host,
      _filePlanner.copyPathCommand(
        normalizedSource,
        normalizedDest,
        recursive: recursive,
      ),
      timeout: timeout,
      onTimeout: onTimeout,
    );
    final verification = await _verifyPathExists(
      host,
      normalizedDest,
      shouldExist: true,
      timeout: timeout,
      onTimeout: onTimeout,
    );
    _resultHandler.emitOutput(
      shell: this,
      host: host,
      operation: 'copyPath',
      run: run,
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
    final normalized = _filePlanner.normalize(path);
    final run = await _runHostCommand(
      host,
      _filePlanner.deletePathCommand(normalized),
      timeout: timeout,
      onTimeout: onTimeout,
    );
    final verification = await _verifyPathExists(
      host,
      normalized,
      shouldExist: false,
      timeout: timeout,
      onTimeout: onTimeout,
    );
    _resultHandler.emitOutput(
      shell: this,
      host: host,
      operation: 'deletePath',
      run: run,
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
    final normalizedSource = _filePlanner.normalize(sourcePath);
    final normalizedDest = _filePlanner.normalize(destinationPath);
    await _ensureRemoteDirectory(
      destinationHost,
      _filePlanner.parentDirectory(normalizedDest),
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
    final run = await _runProcess(
      sourceHost,
      args,
      timeout: timeout,
      onTimeout: onTimeout,
    );
    final verification = await _verifyPathExists(
      destinationHost,
      normalizedDest,
      shouldExist: true,
      timeout: timeout,
      onTimeout: onTimeout,
    );
    _resultHandler.emitOutput(
      shell: this,
      host: destinationHost,
      operation: 'copyBetweenHosts',
      run: run,
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
    final normalizedSource = _filePlanner.normalize(remotePath);
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
    await _runProcess(
      host,
      args,
      timeout: timeout,
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
    final normalizedDest = _filePlanner.normalize(remoteDestination);
    final source = localPath;
    await _ensureRemoteDirectory(
      host,
      _filePlanner.parentDirectory(normalizedDest),
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
    final run = await _runProcess(
      host,
      args,
      timeout: timeout,
      onTimeout: onTimeout,
    );
    final verification = await _verifyPathExists(
      host,
      normalizedDest,
      shouldExist: true,
      timeout: timeout,
      onTimeout: onTimeout,
    );
    _resultHandler.emitOutput(
      shell: this,
      host: host,
      operation: 'uploadPath',
      run: run,
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
    ensureShellAllowed(host);
    _logProcess('Running command on ${host.name}: $command');
    final run = await _runSsh(
      host,
      command,
      timeout: timeout,
      onTimeout: onTimeout,
    );
    final output = _resultHandler.emitOutput(
      shell: this,
      host: host,
      operation: 'runCommand',
      run: run,
    );
    _logProcess(
      'Command on ${host.name} completed. Output length=${output.length}',
    );
    return output;
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
    ensureShellAllowed(host);
    _logProcess('Running command on ${host.name}: $command');
    final run = await _runSshStreaming(
      host,
      command,
      timeout: timeout,
      onTimeout: onTimeout,
      cancellation: cancellation,
      onStdoutLine: onStdoutLine,
      onStderrLine: onStderrLine,
    );
    final output = _resultHandler.emitOutput(
      shell: this,
      host: host,
      operation: 'runCommandStreaming',
      run: run,
    );
    _logProcess(
      'Command on ${host.name} completed. Output length=${output.length}',
    );
    return output;
  }

  @override
  Future<TerminalSession> createTerminalSession(
    SshHost host, {
    required TerminalSessionOptions options,
  }) async {
    ensureShellAllowed(host);
    final columns = options.columns > 0 ? options.columns : 80;
    final rows = options.rows > 0 ? options.rows : 25;
    try {
      final env = _sessionEnvironment();
      LocalPtySession session;
      if (Platform.isWindows) {
        final sshArgs = _runner.buildSshArgumentsForTerminal(host).join(' ');
        final commandLine = 'ssh $sshArgs';
        AppLogger().debug(
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
        AppLogger().debug(
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
          (code) => AppLogger().debug(
            'System SSH session for ${host.name} exited with code $code',
            tag: 'ProcessSSH',
          ),
        ),
      );
      return session;
    } catch (error, stack) {
      AppLogger().warn(
        'Failed to start system SSH session for ${host.name}: $error',
        tag: 'ProcessSSH',
        error: error,
        stackTrace: stack,
      );
      rethrow;
    }
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
    await _runHostCommand(
      host,
      _filePlanner.ensureDirectoryCommand(directory),
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
    final command = _filePlanner.existsCheckCommand(path);
    final run = await _runSsh(
      host,
      command,
      timeout: timeout,
      onTimeout: onTimeout,
    );
    return _resultHandler.verificationFromExistsCheck(
      run: run,
      shouldExist: shouldExist,
    );
  }

  Future<RunResult> _runSsh(
    SshHost host,
    String command, {
    Duration timeout = const Duration(seconds: 10),
    RunTimeoutHandler? onTimeout,
  }) async {
    try {
      return await _runner.runSsh(
        host,
        command,
        timeout: timeout,
        onSshError: _handleSshError,
        onTimeout: onTimeout,
      );
    } catch (error) {
      throw _failureMapper.map(host, error);
    }
  }

  Future<RunResult> _runSshStreaming(
    SshHost host,
    String command, {
    Duration timeout = const Duration(seconds: 10),
    RunTimeoutHandler? onTimeout,
    RemoteCommandCancellation? cancellation,
    void Function(String line)? onStdoutLine,
    void Function(String line)? onStderrLine,
  }) async {
    try {
      return await _runner.runSshStreaming(
        host,
        command,
        timeout: timeout,
        onSshError: _handleSshError,
        onTimeout: onTimeout,
        cancellation: cancellation,
        onStdoutLine: onStdoutLine,
        onStderrLine: onStderrLine,
      );
    } catch (error) {
      if (error is RemoteCommandCancelled) {
        rethrow;
      }
      throw _failureMapper.map(host, error);
    }
  }

  Future<RunResult> _runHostCommand(
    SshHost host,
    String command, {
    Duration timeout = const Duration(seconds: 10),
    RunTimeoutHandler? onTimeout,
  }) async {
    try {
      return await _runner.runHostCommand(
        host,
        command,
        timeout: timeout,
        onSshError: _handleSshError,
        onTimeout: onTimeout,
      );
    } catch (error) {
      throw _failureMapper.map(host, error);
    }
  }

  Future<RunResult> _runProcess(
    SshHost host,
    List<String> command, {
    Duration timeout = const Duration(seconds: 10),
    RunTimeoutHandler? onTimeout,
  }) async {
    try {
      return await _runner.runProcess(
        command,
        timeout: timeout,
        hostForErrors: host,
        onSshError: _handleSshError,
        onTimeout: onTimeout,
      );
    } catch (error) {
      throw _failureMapper.map(host, error);
    }
  }
}

void _logProcess(String message) {
  AppLogger().debug(message, tag: 'ProcessSSH');
}
