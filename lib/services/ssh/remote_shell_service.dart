import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../../models/remote_file_entry.dart';
import '../../models/ssh_host.dart';

class RemoteShellService {
  const RemoteShellService();

  Future<List<RemoteFileEntry>> listDirectory(
    SshHost host,
    String path, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final sanitizedPath = _sanitizePath(path);
    final lsCommand = "cd '${_escapeSingleQuotes(sanitizedPath)}' && ls -al --time-style=+%Y-%m-%dT%H:%M:%S";
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
      final stderrOutput = (result.stderr as String?)?.trim();
      throw Exception(stderrOutput?.isNotEmpty == true ? stderrOutput : 'SSH exited with ${result.exitCode}');
    }

    return _parseLsOutput(result.stdout as String, sanitizedPath);
  }

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
      final message = (result.stderr as String?)?.trim();
      throw Exception(message?.isNotEmpty == true ? message : 'Failed to read file');
    }
    return result.stdout as String? ?? '';
  }

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
      final message = (result.stderr as String?)?.trim();
      throw Exception(message?.isNotEmpty == true ? message : 'Failed to write file');
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

  String _randomDelimiter() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random();
    return List.generate(12, (index) => chars[rand.nextInt(chars.length)]).join();
  }

  List<RemoteFileEntry> _parseLsOutput(String stdout, String currentPath) {
    final lines = const LineSplitter().convert(stdout);

    final entries = <RemoteFileEntry>[];
    for (final line in lines) {
      if (line.isEmpty || line.startsWith('total')) {
        continue;
      }
      final parsed = _parseLine(line);
      if (parsed != null) {
        entries.add(parsed);
      }
    }
    return entries;
  }

  RemoteFileEntry? _parseLine(String line) {
    final pattern = RegExp(
      r'^([\-ldcbps])([rwx\-]{9})\s+\d+\s+\S+\s+\S+\s+(\d+)\s+(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})\s+(.+)$',
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
