import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../../models/remote_file_entry.dart';
import '../../models/ssh_host.dart';
import 'remote_ls_parser.dart';

abstract class RemoteShellService {
  const RemoteShellService();

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
  const ProcessRemoteShellService();

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
    final result = await Process.run(
      'ssh',
      [
        '-o',
        'BatchMode=yes',
        '-o',
        'StrictHostKeyChecking=no',
        host.name,
        lsCommand,
      ],
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
      runInShell: false,
    ).timeout(timeout);

    if (result.exitCode != 0) {
      _handleSshError(host, result);
    }

    return parseLsOutput(result.stdout as String);
  }

  @override
  Future<String> homeDirectory(
    SshHost host, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final result = await Process.run(
      'ssh',
      [
        '-o',
        'BatchMode=yes',
        '-o',
        'StrictHostKeyChecking=no',
        host.name,
        'echo \$HOME',
      ],
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
      runInShell: false,
    ).timeout(timeout);
    if (result.exitCode != 0) {
      return '/';
    }
    final output = (result.stdout as String?)?.trim();
    return (output == null || output.isEmpty) ? '/' : output;
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
    final result = await Process.run(
      'ssh',
      command,
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
      runInShell: false,
    ).timeout(timeout);

    if (result.exitCode != 0) {
      _handleSshError(host, result);
    }
    return result.stdout as String? ?? '';
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

    final result = await Process.run(
      'ssh',
      command,
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
      runInShell: false,
    ).timeout(timeout);

    if (result.exitCode != 0) {
      _handleSshError(host, result);
    }
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
    await _runHostCommand(
      host,
      "mv '${_escapeSingleQuotes(normalizedSource)}' '${_escapeSingleQuotes(normalizedDest)}'",
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
  }) async {
    final normalizedSource = _sanitizePath(source);
    final normalizedDest = _sanitizePath(destination);
    await _ensureRemoteDirectory(host, _dirname(normalizedDest));
    final flag = recursive ? '-R ' : '';
    await _runHostCommand(
      host,
      "cp $flag'${_escapeSingleQuotes(normalizedSource)}' '${_escapeSingleQuotes(normalizedDest)}'",
      timeout: timeout,
    );
  }

  @override
  Future<void> deletePath(
    SshHost host,
    String path, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final normalized = _sanitizePath(path);
    await _runHostCommand(
      host,
      "rm -rf '${_escapeSingleQuotes(normalized)}'",
      timeout: timeout,
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
    final result = await Process.run(
      'bash',
      ['-lc', command],
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    ).timeout(timeout);
    if (result.exitCode != 0) {
      _handleSshError(sourceHost, result);
    }
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
    final result = await Process.run(
      'bash',
      ['-lc', command],
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    ).timeout(timeout);
    if (result.exitCode != 0) {
      _handleSshError(host, result);
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
    final result = await Process.run(
      'bash',
      ['-lc', command],
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    ).timeout(timeout);
    if (result.exitCode != 0) {
      _handleSshError(host, result);
    }
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

  Future<void> _runHostCommand(
    SshHost host,
    String command, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final result = await Process.run(
      'ssh',
      [
        '-o',
        'BatchMode=yes',
        '-o',
        'StrictHostKeyChecking=no',
        host.name,
        command,
      ],
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
      runInShell: false,
    ).timeout(timeout);
    if (result.exitCode != 0) {
      _handleSshError(host, result);
    }
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
}
