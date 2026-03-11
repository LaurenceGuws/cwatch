import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cwatch/model/models/remote_file_entry.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import '../logging/app_logger.dart';
import 'process_ssh_command_support.dart';
import 'process_ssh_file_operation_planner.dart';
import 'process_ssh_search_planner.dart';
import 'process_ssh_run_result_handler.dart';
import 'process_ssh_terminal_session_planner.dart';
import 'process_ssh_execution_adapter.dart';
import 'process_ssh_path_support.dart';
import 'process_ssh_transfer_support.dart';
import 'process_ssh_failure_mapper.dart';
import 'remote_shell_base.dart';
import 'terminal_session.dart';
import 'process_ssh_runner.dart';

class ProcessRemoteShellService extends RemoteShellService {
  ProcessRemoteShellService({
    super.debugMode = false,
    super.observer,
    ProcessSshRunner? runner,
    ProcessSshFailureMapper? failureMapper,
    ProcessSshExecutionAdapter? executionAdapter,
  }) : _runner = runner ?? const ProcessSshRunner(),
       _failureMapper = failureMapper ?? const ProcessSshFailureMapper(),
       _executionAdapter =
           executionAdapter ??
           ProcessSshExecutionAdapter(
             runner: runner,
             failureMapper: failureMapper,
           );

  final ProcessSshRunner _runner;
  final ProcessSshFailureMapper _failureMapper;
  final ProcessSshExecutionAdapter _executionAdapter;
  final ProcessSshRunResultHandler _resultHandler =
      const ProcessSshRunResultHandler();
  final ProcessSshCommandSupport _commandSupport =
      const ProcessSshCommandSupport();
  final ProcessSshFileOperationPlanner _filePlanner =
      const ProcessSshFileOperationPlanner();
  final ProcessSshSearchPlanner _searchPlanner =
      const ProcessSshSearchPlanner();
  final ProcessSshTerminalSessionPlanner _terminalSessionPlanner =
      const ProcessSshTerminalSessionPlanner();
  final ProcessSshPathSupport _pathSupport = const ProcessSshPathSupport();
  final ProcessSshTransferSupport _transferSupport =
      const ProcessSshTransferSupport();

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
      _commandSupport.emitCommandOutput(
        shell: this,
        host: host,
        operation: 'listDirectory',
        run: run,
        trimOutput: true,
      );
      return parseLsOutput(run.stdout);
    } catch (error) {
      _commandSupport.logFailure(
        host: host,
        operation: 'listDirectory',
        command: lsCommand,
        error: error,
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
      final output = _commandSupport.emitCommandOutput(
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
    final verification = await _pathSupport.verifyPathExists(
      host,
      normalized,
      shouldExist: true,
      debugMode: debugMode,
      runSsh: (targetHost, command) => _runSsh(
        targetHost,
        command,
        timeout: timeout,
        onTimeout: onTimeout,
      ),
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
    await _pathSupport.ensureRemoteDirectory(
      host,
      _filePlanner.parentDirectory(normalizedDest),
      runHostCommand: (targetHost, command) => _runHostCommand(
        targetHost,
        command,
        onTimeout: onTimeout,
      ),
    );
    final run = await _runHostCommand(
      host,
      _filePlanner.movePathCommand(normalizedSource, normalizedDest),
      timeout: timeout,
      onTimeout: onTimeout,
    );
    final verification = await _pathSupport.verifyPathExists(
      host,
      normalizedDest,
      shouldExist: true,
      debugMode: debugMode,
      runSsh: (targetHost, command) => _runSsh(
        targetHost,
        command,
        timeout: timeout,
        onTimeout: onTimeout,
      ),
    );
    final sourceGone = await _pathSupport.verifyPathExists(
      host,
      normalizedSource,
      shouldExist: false,
      debugMode: debugMode,
      runSsh: (targetHost, command) => _runSsh(
        targetHost,
        command,
        timeout: timeout,
        onTimeout: onTimeout,
      ),
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
    await _pathSupport.ensureRemoteDirectory(
      host,
      _filePlanner.parentDirectory(normalizedDest),
      runHostCommand: (targetHost, command) => _runHostCommand(
        targetHost,
        command,
        onTimeout: onTimeout,
      ),
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
    final verification = await _pathSupport.verifyPathExists(
      host,
      normalizedDest,
      shouldExist: true,
      debugMode: debugMode,
      runSsh: (targetHost, command) => _runSsh(
        targetHost,
        command,
        timeout: timeout,
        onTimeout: onTimeout,
      ),
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
    final verification = await _pathSupport.verifyPathExists(
      host,
      normalized,
      shouldExist: false,
      debugMode: debugMode,
      runSsh: (targetHost, command) => _runSsh(
        targetHost,
        command,
        timeout: timeout,
        onTimeout: onTimeout,
      ),
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
    await _pathSupport.ensureRemoteDirectory(
      destinationHost,
      _filePlanner.parentDirectory(normalizedDest),
      runHostCommand: (targetHost, command) => _runHostCommand(
        targetHost,
        command,
        onTimeout: onTimeout,
      ),
    );
    final sharedPort = sourceHost.port == destinationHost.port
        ? sourceHost.port
        : null;
    final args =
        _transferSupport.buildScpArgs(
            identityFiles: {
              ...sourceHost.identityFiles,
              ...destinationHost.identityFiles,
            },
            recursive: recursive,
            remotePort: sharedPort,
            extraFlags: const ['-3'],
          )
          ..add(
            _transferSupport.formatRemoteSpec(
              sourceHost,
              normalizedSource,
              connectionTarget: _runner.connectionTarget(sourceHost),
            ),
          )
          ..add(
            _transferSupport.formatRemoteSpec(
              destinationHost,
              normalizedDest,
              connectionTarget: _runner.connectionTarget(destinationHost),
            ),
          );
    final run = await _runProcess(
      sourceHost,
      args,
      timeout: timeout,
      onTimeout: onTimeout,
    );
    final verification = await _pathSupport.verifyPathExists(
      destinationHost,
      normalizedDest,
      shouldExist: true,
      debugMode: debugMode,
      runSsh: (targetHost, command) => _runSsh(
        targetHost,
        command,
        timeout: timeout,
        onTimeout: onTimeout,
      ),
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
        _transferSupport.buildScpArgs(
            identityFiles: host.identityFiles.toSet(),
            remotePort: host.port,
            recursive: recursive,
          )
          ..add(
            _transferSupport.formatRemoteSpec(
              host,
              normalizedSource,
              connectionTarget: _runner.connectionTarget(host),
            ),
          )
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
    await _pathSupport.ensureRemoteDirectory(
      host,
      _filePlanner.parentDirectory(normalizedDest),
      runHostCommand: (targetHost, command) => _runHostCommand(
        targetHost,
        command,
        onTimeout: onTimeout,
      ),
    );
    final args =
        _transferSupport.buildScpArgs(
            identityFiles: host.identityFiles.toSet(),
            remotePort: host.port,
            recursive: recursive,
          )
          ..add(source)
          ..add(
            _transferSupport.formatRemoteSpec(
              host,
              normalizedDest,
              connectionTarget: _runner.connectionTarget(host),
            ),
          );
    final run = await _runProcess(
      host,
      args,
      timeout: timeout,
      onTimeout: onTimeout,
    );
    final verification = await _pathSupport.verifyPathExists(
      host,
      normalizedDest,
      shouldExist: true,
      debugMode: debugMode,
      runSsh: (targetHost, command) => _runSsh(
        targetHost,
        command,
        timeout: timeout,
        onTimeout: onTimeout,
      ),
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
    _commandSupport.logCommandStart(host: host, command: command);
    final run = await _runSsh(
      host,
      command,
      timeout: timeout,
      onTimeout: onTimeout,
    );
    final output = _commandSupport.emitCommandOutput(
      shell: this,
      host: host,
      operation: 'runCommand',
      run: run,
    );
    _commandSupport.logCommandComplete(host: host, output: output);
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
    _commandSupport.logCommandStart(host: host, command: command);
    final run = await _runSshStreaming(
      host,
      command,
      timeout: timeout,
      onTimeout: onTimeout,
      cancellation: cancellation,
      onStdoutLine: onStdoutLine,
      onStderrLine: onStderrLine,
    );
    final output = _commandSupport.emitCommandOutput(
      shell: this,
      host: host,
      operation: 'runCommandStreaming',
      run: run,
    );
    _commandSupport.logCommandComplete(host: host, output: output);
    return output;
  }

  @override
  Future<TerminalSession> createTerminalSession(
    SshHost host, {
    required TerminalSessionOptions options,
  }) async {
    ensureShellAllowed(host);
    try {
      final plan = _terminalSessionPlanner.createPlan(
        host: host,
        options: options,
        runner: _runner,
      );
      AppLogger().debug(
        'Starting system SSH via ${plan.debugCommand}',
        tag: 'ProcessSSH',
      );
      final session = LocalPtySession(
        executable: plan.executable,
        arguments: plan.arguments,
        environment: plan.environment,
        cols: plan.columns,
        rows: plan.rows,
      );
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
  Future<RunResult> _runSsh(
    SshHost host,
    String command, {
    Duration timeout = const Duration(seconds: 10),
    RunTimeoutHandler? onTimeout,
  }) async {
    try {
      return await _executionAdapter.runSsh(
        host,
        command,
        timeout: timeout,
        onSshError: _handleSshError,
        onTimeout: onTimeout,
      );
    } catch (error) {
      rethrow;
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
      return await _executionAdapter.runSshStreaming(
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
      rethrow;
    }
  }

  Future<RunResult> _runHostCommand(
    SshHost host,
    String command, {
    Duration timeout = const Duration(seconds: 10),
    RunTimeoutHandler? onTimeout,
  }) async {
    try {
      return await _executionAdapter.runHostCommand(
        host,
        command,
        timeout: timeout,
        onSshError: _handleSshError,
        onTimeout: onTimeout,
      );
    } catch (error) {
      rethrow;
    }
  }

  Future<RunResult> _runProcess(
    SshHost host,
    List<String> command, {
    Duration timeout = const Duration(seconds: 10),
    RunTimeoutHandler? onTimeout,
  }) async {
    try {
      return await _executionAdapter.runProcess(
        host,
        command,
        timeout: timeout,
        onSshError: _handleSshError,
        onTimeout: onTimeout,
      );
    } catch (error) {
      rethrow;
    }
  }
}
