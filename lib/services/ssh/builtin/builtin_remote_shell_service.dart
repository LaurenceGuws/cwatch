import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cwatch/models/remote_file_entry.dart';
import 'package:cwatch/models/ssh_host.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:path/path.dart' as p;

import '../remote_shell_service.dart';
import '../terminal_session.dart';
import 'builtin_sftp_transfer.dart';
import 'builtin_ssh_client_manager.dart';
import 'builtin_ssh_logging.dart';
import 'builtin_ssh_vault.dart';
import 'builtin_terminal_session.dart';
import '../known_hosts_store.dart';
import '../ssh_auth_coordinator.dart';
export 'builtin_ssh_exceptions.dart';

class BuiltInRemoteShellService extends RemoteShellService {
  BuiltInRemoteShellService({
    required this.vault,
    Map<String, String>? hostKeyBindings,
    this.connectTimeout = const Duration(seconds: 10),
    super.debugMode = false,
    super.observer,
    this.promptUnlock,
    KnownHostsStore? knownHostsStore,
    SshAuthCoordinator? authCoordinator,
  }) : _clientManager = BuiltInSshClientManager(
         vault: vault,
         hostKeyBindings: hostKeyBindings ?? const {},
         connectTimeout: connectTimeout,
         knownHostsStore: knownHostsStore,
         authCoordinator:
             authCoordinator ??
             (promptUnlock != null
                 ? SshAuthCoordinator().withUnlockFallback(promptUnlock)
                 : const SshAuthCoordinator()),
       ) {
    _sftpTransfer = BuiltInSftpTransfer(_clientManager);
  }

  final BuiltInSshVault vault;
  final Duration connectTimeout;
  final Future<bool> Function(String keyId, String hostName, String? keyLabel)?
  promptUnlock;
  final BuiltInSshClientManager _clientManager;
  late final BuiltInSftpTransfer _sftpTransfer;

  @override
  Future<List<RemoteFileEntry>> listDirectory(
    SshHost host,
    String path, {
    Duration timeout = const Duration(seconds: 10),
    RunTimeoutHandler? onTimeout,
  }) async {
    final sanitized = sanitizePath(path);
    final command =
        "cd '${escapeSingleQuotes(sanitized)}' && ls -al --time-style=+%Y-%m-%dT%H:%M:%S";
    final output = await _clientManager.runCommand(
      host,
      command,
      timeout: timeout,
      onTimeout: onTimeout,
    );
    logBuiltInSsh(
      'listDirectory output for ${host.name}:$path (length=${output.length})',
    );
    logBuiltInSsh(
      'First 500 chars: ${output.length > 500 ? output.substring(0, 500) : output}',
    );
    final entries = parseLsOutput(output);
    logBuiltInSsh('Parsed ${entries.length} entries from output');
    return entries;
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
    String commandLog;
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
        basePath: sanitized,
      );
      final prunePrefix = excludePrune.isEmpty
          ? ''
          : "\\( -type d \\( $excludePrune \\) -prune \\) -o ";
      final filesCommand =
          "$commandBase find . $prunePrefix\\( ${buildPredicate('f', includeName: false)} \\) -exec grep $grepFlags -- '$escapedQuery' {} + 2>/dev/null || true";
      dirOutput = '';
      fileOutput = await _clientManager.runCommandStreaming(
        host,
        filesCommand,
        timeout: effectiveTimeout,
        onTimeout: onTimeout,
        cancellation: cancellation,
        onStdoutLine: (line) {
          addEntries(line, isDirectory: false);
        },
      );
      commandLog = filesCommand;
    } else {
      final printFlag =
          onEntry != null ? "-exec printf '%s\\n' {} \\;" : '-print';
      final dirsCommand =
          "$commandBase find . ${buildPredicate('d', includeName: true)} $printFlag 2>/dev/null || true";
      final filesCommand =
          "$commandBase find . ${buildPredicate('f', includeName: true)} $printFlag 2>/dev/null || true";
      final dirFuture = _clientManager.runCommandStreaming(
        host,
        dirsCommand,
        timeout: effectiveTimeout,
        onTimeout: onTimeout,
        cancellation: cancellation,
        onStdoutLine: (line) {
          addEntries(line, isDirectory: true);
        },
      );
      final fileFuture = _clientManager.runCommandStreaming(
        host,
        filesCommand,
        timeout: effectiveTimeout,
        onTimeout: onTimeout,
        cancellation: cancellation,
        onStdoutLine: (line) {
          addEntries(line, isDirectory: false);
        },
      );
      final outputs = await Future.wait([dirFuture, fileFuture]);
      dirOutput = outputs[0];
      fileOutput = outputs[1];
      commandLog = '$dirsCommand\n$filesCommand';
    }
    if (searchContents) {
      addEntries(dirOutput, isDirectory: true);
    }
    emitDebugEvent(
      host: host,
      operation: 'searchPaths',
      command: commandLog,
      output: '${dirOutput.trimRight()}\n${fileOutput.trimRight()}',
    );
    return entries;
  }

  @override
  Future<String> homeDirectory(
    SshHost host, {
    Duration timeout = const Duration(seconds: 5),
    RunTimeoutHandler? onTimeout,
  }) async {
    final output = await _clientManager.runCommand(
      host,
      'echo \$HOME',
      timeout: timeout,
      onTimeout: onTimeout,
    );
    final trimmed = output.trim();
    return trimmed.isEmpty ? '/' : trimmed;
  }

  @override
  Future<String> readFile(
    SshHost host,
    String path, {
    Duration timeout = const Duration(seconds: 15),
    RunTimeoutHandler? onTimeout,
  }) async {
    final normalized = sanitizePath(path);
    final command = "cat '${escapeSingleQuotes(normalized)}'";
    final output = await _clientManager.runCommand(
      host,
      command,
      timeout: timeout,
      onTimeout: onTimeout,
    );
    return output;
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
    final command =
        "base64 -d > '${escapeSingleQuotes(normalized)}' <<'$delimiter'\n$encoded\n$delimiter";
    final output = await _clientManager.runCommand(
      host,
      command,
      timeout: timeout,
      onTimeout: onTimeout,
    );
    final verification = await _verifyRemotePath(
      host,
      normalized,
      shouldExist: true,
      timeout: timeout,
      onTimeout: onTimeout,
    );
    emitDebugEvent(
      host: host,
      operation: 'writeFile',
      command: command,
      output: output,
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
    final run = await _clientManager.runRemoteCommand(
      host,
      "mv '${escapeSingleQuotes(normalizedSource)}' '${escapeSingleQuotes(normalizedDest)}'",
      timeout: timeout,
      onTimeout: onTimeout,
    );
    final verification = await _verifyRemotePath(
      host,
      normalizedDest,
      shouldExist: true,
      timeout: timeout,
      onTimeout: onTimeout,
    );
    final sourceGone = await _verifyRemotePath(
      host,
      normalizedSource,
      shouldExist: false,
      timeout: timeout,
      onTimeout: onTimeout,
    );
    emitDebugEvent(
      host: host,
      operation: 'movePath',
      command: run.command,
      output: run.stdout,
      verification: verification?.combine(sourceGone),
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
    final flag = recursive ? '-R ' : '';
    final run = await _clientManager.runRemoteCommand(
      host,
      "cp $flag'${escapeSingleQuotes(normalizedSource)}' '${escapeSingleQuotes(normalizedDest)}'",
      timeout: timeout,
      onTimeout: onTimeout,
    );
    final verification = await _verifyRemotePath(
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
    final run = await _clientManager.runRemoteCommand(
      host,
      "rm -rf '${escapeSingleQuotes(normalized)}'",
      timeout: timeout,
      onTimeout: onTimeout,
    );
    final verification = await _verifyRemotePath(
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
    final tempDir = await Directory.systemTemp.createTemp(
      'cwatch-ssh-copy-${DateTime.now().microsecondsSinceEpoch}',
    );
    try {
      await downloadPath(
        host: sourceHost,
        remotePath: sourcePath,
        localDestination: tempDir.path,
        recursive: recursive,
        timeout: timeout,
        onTimeout: onTimeout,
      );
      final localRoot = p.join(tempDir.path, p.basename(sourcePath));
      await uploadPath(
        host: destinationHost,
        localPath: localRoot,
        remoteDestination: destinationPath,
        recursive: recursive,
        timeout: timeout,
        onTimeout: onTimeout,
      );
    } finally {
      await tempDir.delete(recursive: true);
    }
    final verification = await _verifyRemotePath(
      destinationHost,
      sanitizePath(destinationPath),
      shouldExist: true,
      timeout: const Duration(seconds: 10),
      onTimeout: onTimeout,
    );
    emitDebugEvent(
      host: destinationHost,
      operation: 'copyBetweenHosts',
      command:
          'sftp copy ${sourceHost.name}:$sourcePath -> ${destinationHost.name}:$destinationPath',
      output: 'completed',
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
  }) {
    return _sftpTransfer.downloadPath(
      host: host,
      remotePath: remotePath,
      localDestination: localDestination,
      recursive: recursive,
      timeout: timeout,
      onBytes: onBytes,
      onTimeout: onTimeout,
    );
  }

  @override
  Future<void> downloadPaths({
    required SshHost host,
    required List<RemotePathDownload> downloads,
    Duration timeout = const Duration(minutes: 2),
    void Function(RemotePathDownload download, Object error)? onError,
    RunTimeoutHandler? onTimeout,
  }) {
    return _sftpTransfer.downloadPaths(
      host: host,
      downloads: downloads,
      timeout: timeout,
      onError: onError,
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
    await _sftpTransfer.uploadPath(
      host: host,
      localPath: localPath,
      remoteDestination: remoteDestination,
      recursive: recursive,
      timeout: timeout,
      onBytes: onBytes,
      onTimeout: onTimeout,
    );
    final verification = await _verifyRemotePath(
      host,
      sanitizePath(remoteDestination),
      shouldExist: true,
      timeout: const Duration(seconds: 10),
      onTimeout: onTimeout,
    );
    emitDebugEvent(
      host: host,
      operation: 'uploadPath',
      command:
          'sftp upload user=${host.user ?? 'root'} $localPath -> $remoteDestination',
      output: 'completed',
      verification: verification,
    );
  }

  Future<void> uploadBytes({
    required SshHost host,
    required List<int> bytes,
    required String remoteDestination,
    Duration timeout = const Duration(minutes: 2),
    RunTimeoutHandler? onTimeout,
  }) async {
    await _sftpTransfer.uploadBytes(
      host: host,
      bytes: bytes,
      remoteDestination: remoteDestination,
      timeout: timeout,
      onTimeout: onTimeout,
    );
    final verification = await _verifyRemotePath(
      host,
      sanitizePath(remoteDestination),
      shouldExist: true,
      timeout: const Duration(seconds: 10),
      onTimeout: onTimeout,
    );
    emitDebugEvent(
      host: host,
      operation: 'uploadBytes',
      command: 'sftp upload <bytes> -> $remoteDestination',
      output: 'completed',
      verification: verification,
    );
  }

  @override
  Future<String> runCommand(
    SshHost host,
    String command, {
    Duration timeout = const Duration(seconds: 10),
    RunTimeoutHandler? onTimeout,
  }) {
    return _clientManager.runCommand(
      host,
      command,
      timeout: timeout,
      onTimeout: onTimeout,
    );
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
  }) {
    return _clientManager.runCommandStreaming(
      host,
      command,
      timeout: timeout,
      onTimeout: onTimeout,
      cancellation: cancellation,
      onStdoutLine: onStdoutLine,
      onStderrLine: onStderrLine,
    );
  }

  @override
  Future<TerminalSession> createTerminalSession(
    SshHost host, {
    required TerminalSessionOptions options,
  }) async {
    SSHClient? client;
    try {
      client = await _clientManager.openPersistentClient(host);
      final config = SSHPtyConfig(
        width: options.columns > 0 ? options.columns : 80,
        height: options.rows > 0 ? options.rows : 25,
        pixelWidth: options.pixelWidth,
        pixelHeight: options.pixelHeight,
      );
      final session = await client.shell(pty: config);
      return BuiltInTerminalSession(
        client: client,
        session: session,
        rows: options.rows > 0 ? options.rows : 25,
        columns: options.columns > 0 ? options.columns : 80,
      );
    } catch (error) {
      client?.close();
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

  String? getActiveBuiltInKeyId(SshHost host) {
    return _clientManager.boundKeyForHost(host.name);
  }

  void setIdentityPassphrase(String identityPath, String passphrase) {
    _clientManager.setIdentityPassphrase(identityPath, passphrase);
  }

  void setBuiltInKeyPassphrase(String keyId, String passphrase) {
    _clientManager.setBuiltInKeyPassphrase(keyId, passphrase);
  }

  Future<VerificationResult?> _verifyRemotePath(
    SshHost host,
    String path, {
    required bool shouldExist,
    Duration timeout = const Duration(seconds: 8),
    RunTimeoutHandler? onTimeout,
  }) async {
    if (!debugMode) {
      return null;
    }
    final command =
        "[ -e '${escapeSingleQuotes(path)}' ] && echo 'EXISTS' || echo 'MISSING'";
    final output = await _clientManager.runCommand(
      host,
      command,
      timeout: timeout,
      onTimeout: onTimeout,
    );
    final exists = output.trim() == 'EXISTS';
    return VerificationResult(
      command: command,
      output: output,
      passed: shouldExist ? exists : !exists,
    );
  }
}
