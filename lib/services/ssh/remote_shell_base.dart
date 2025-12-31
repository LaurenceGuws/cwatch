import 'dart:convert';

import 'package:meta/meta.dart';

import '../../models/remote_file_entry.dart';
import '../../models/ssh_host.dart';
import '../logging/app_logger.dart';
import 'terminal_session.dart';
import 'remote_path_utils.dart';

class TerminalSessionOptions {
  const TerminalSessionOptions({
    this.rows = 25,
    this.columns = 80,
    this.pixelWidth = 0,
    this.pixelHeight = 0,
  });

  final int rows;
  final int columns;
  final int pixelWidth;
  final int pixelHeight;
}

typedef VoidCallback = void Function();

class RemotePathDownload {
  const RemotePathDownload({
    required this.remotePath,
    required this.localDestination,
    this.recursive = false,
    this.onBytes,
  });

  final String remotePath;
  final String localDestination;
  final bool recursive;
  final void Function(int bytesTransferred)? onBytes;
}

/// Base contract for remote shell operations used across modules.
abstract class RemoteShellService with RemotePathUtils {
  const RemoteShellService({this.debugMode = false, this.observer});

  final bool debugMode;
  final RemoteCommandObserver? observer;

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
        source: 'ssh',
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
      AppLogger.w(
        'Verification failed for $operation on ${host.name}',
        tag: 'SSH DEBUG',
      );
    }
  }

  Future<List<RemoteFileEntry>> listDirectory(
    SshHost host,
    String path, {
    Duration timeout = const Duration(seconds: 10),
    RunTimeoutHandler? onTimeout,
  });

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
  });

  Future<String> homeDirectory(
    SshHost host, {
    Duration timeout = const Duration(seconds: 5),
    RunTimeoutHandler? onTimeout,
  });

  Future<String> readFile(
    SshHost host,
    String path, {
    Duration timeout = const Duration(seconds: 15),
    RunTimeoutHandler? onTimeout,
  });

  Future<void> writeFile(
    SshHost host,
    String path,
    String contents, {
    Duration timeout = const Duration(seconds: 15),
    RunTimeoutHandler? onTimeout,
  });

  Future<void> movePath(
    SshHost host,
    String source,
    String destination, {
    Duration timeout = const Duration(seconds: 15),
    RunTimeoutHandler? onTimeout,
  });

  Future<void> copyPath(
    SshHost host,
    String source,
    String destination, {
    bool recursive = false,
    Duration timeout = const Duration(seconds: 20),
    RunTimeoutHandler? onTimeout,
  });

  Future<void> deletePath(
    SshHost host,
    String path, {
    Duration timeout = const Duration(seconds: 15),
    RunTimeoutHandler? onTimeout,
  });

  Future<void> copyBetweenHosts({
    required SshHost sourceHost,
    required String sourcePath,
    required SshHost destinationHost,
    required String destinationPath,
    bool recursive = false,
    Duration timeout = const Duration(minutes: 2),
    RunTimeoutHandler? onTimeout,
  });

  Future<void> downloadPath({
    required SshHost host,
    required String remotePath,
    required String localDestination,
    bool recursive = false,
    Duration timeout = const Duration(minutes: 2),
    void Function(int bytesTransferred)? onBytes,
    RunTimeoutHandler? onTimeout,
  });

  Future<void> downloadPaths({
    required SshHost host,
    required List<RemotePathDownload> downloads,
    Duration timeout = const Duration(minutes: 2),
    void Function(RemotePathDownload download, Object error)? onError,
    RunTimeoutHandler? onTimeout,
  }) async {
    for (final download in downloads) {
      try {
        await downloadPath(
          host: host,
          remotePath: download.remotePath,
          localDestination: download.localDestination,
          recursive: download.recursive,
          timeout: timeout,
          onBytes: download.onBytes,
          onTimeout: onTimeout,
        );
      } catch (error, stackTrace) {
        if (onError == null) {
          AppLogger.w(
            'Failed to download ${download.remotePath}',
            tag: 'SSH',
            error: error,
            stackTrace: stackTrace,
          );
          rethrow;
        }
        AppLogger.w(
          'Failed to download ${download.remotePath}',
          tag: 'SSH',
          error: error,
          stackTrace: stackTrace,
        );
        onError(download, error);
      }
    }
  }

  Future<void> uploadPath({
    required SshHost host,
    required String localPath,
    required String remoteDestination,
    bool recursive = false,
    Duration timeout = const Duration(minutes: 2),
    void Function(int bytesTransferred)? onBytes,
    RunTimeoutHandler? onTimeout,
  });

  Future<String> runCommand(
    SshHost host,
    String command, {
    Duration timeout = const Duration(seconds: 10),
    RunTimeoutHandler? onTimeout,
  });

  Future<String> runCommandStreaming(
    SshHost host,
    String command, {
    Duration timeout = const Duration(seconds: 10),
    RunTimeoutHandler? onTimeout,
    RemoteCommandCancellation? cancellation,
    void Function(String line)? onStdoutLine,
    void Function(String line)? onStderrLine,
  }) async {
    if (cancellation?.isCancelled == true) {
      throw const RemoteCommandCancelled();
    }
    final output = await runCommand(
      host,
      command,
      timeout: timeout,
      onTimeout: onTimeout,
    );
    if (cancellation?.isCancelled == true) {
      throw const RemoteCommandCancelled();
    }
    if (onStdoutLine != null) {
      for (final line in const LineSplitter().convert(output)) {
        onStdoutLine(line);
      }
    }
    return output;
  }

  Future<TerminalSession> createTerminalSession(
    SshHost host, {
    required TerminalSessionOptions options,
  });

  @protected
  List<RemoteFileEntry> parseLsOutput(String stdout) {
    final lines = const LineSplitter().convert(stdout);
    final entries = <RemoteFileEntry>[];
    for (final line in lines) {
      if (line.isEmpty || line.startsWith('total')) {
        continue;
      }
      final parsed = _parseLsLine(line);
      if (parsed != null) {
        entries.add(parsed);
      }
    }
    return entries;
  }

  RemoteFileEntry? _parseLsLine(String line) {
    // Handle ACL/SELinux indicators (+/@) and symlink targets.
    final pattern = RegExp(
      r'^([\-ldcbps])([rwx\-+@]{9,11})\s+\d+\s+\S+\s+\S+\s+(\d+)\s+(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})\s+(.+)$',
    );
    final match = pattern.firstMatch(line);
    if (match == null) {
      return null;
    }
    final typeFlag = match.group(1)!;
    final size = int.tryParse(match.group(3) ?? '') ?? 0;
    final modified = DateTime.tryParse(match.group(4) ?? '') ?? DateTime.now();
    var name = match.group(5) ?? '';
    if (typeFlag == 'l') {
      final parts = name.split(' -> ');
      name = parts.first;
    }
    final isDirectory = typeFlag == 'd' || typeFlag == 'l';
    return RemoteFileEntry(
      name: name,
      isDirectory: isDirectory,
      sizeBytes: size,
      modified: modified,
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

class RemoteCommandCancellation {
  bool _cancelled = false;
  final List<VoidCallback> _handlers = [];

  bool get isCancelled => _cancelled;

  void cancel() {
    if (_cancelled) {
      return;
    }
    _cancelled = true;
    for (final handler in List<VoidCallback>.from(_handlers)) {
      handler();
    }
  }

  void onCancel(VoidCallback handler) {
    if (_cancelled) {
      handler();
      return;
    }
    _handlers.add(handler);
  }
}

class RemoteCommandCancelled implements Exception {
  const RemoteCommandCancelled();

  @override
  String toString() => 'RemoteCommandCancelled';
}

/// Describes how a long-running command should behave when it hits a timeout
/// boundary. `wait` allows the caller to extend the wait window, while `kill`
/// should terminate the underlying process or connection.
class TimeoutResolution {
  const TimeoutResolution._(this.shouldKill, this.extendBy);

  const TimeoutResolution.kill() : this._(true, null);
  const TimeoutResolution.wait([Duration? extendBy]) : this._(false, extendBy);

  final bool shouldKill;
  final Duration? extendBy;
}

class TimeoutContext {
  TimeoutContext({
    required this.host,
    required this.commandDescription,
    required this.elapsed,
  });

  final SshHost? host;
  final String commandDescription;
  final Duration elapsed;
}

typedef RunTimeoutHandler =
    Future<TimeoutResolution> Function(TimeoutContext context);

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
    ].where((element) => element.isNotEmpty).join('\\n');
    return VerificationResult(
      command: '$command && ${other.command}',
      output: combinedOutput,
      passed: passed && other.passed,
    );
  }
}
