import 'dart:io';

import '../../models/custom_ssh_host.dart';
import '../../models/ssh_host.dart';
import '../logging/app_logger.dart';
import 'config_sources/config_source.dart';

class SshConfigParser {
  const SshConfigParser();

  Future<List<ParsedHost>> collectEntries(
    String path,
    Set<String> visited, {
    Set<String>? blockedPaths,
  }) async {
    final file = File(path);
    if (!await file.exists()) {
      return [];
    }

    final canonicalPath = await _canonicalize(file);
    if (blockedPaths != null && blockedPaths.contains(canonicalPath)) {
      return [];
    }
    if (!visited.add(canonicalPath)) {
      return [];
    }

    List<String> lines;
    try {
      lines = await file.readAsLines();
    } on FileSystemException {
      // If the descriptor limit is hit or the file becomes unavailable, skip it gracefully.
      visited.remove(canonicalPath);
      return [];
    }
    final hosts = <ParsedHost>[];
    String? currentName;
    String? hostname;
    int port = 22;
    String? user;
    final identityFiles = <String>[];

    void commit() {
      if (currentName != null && hostname != null) {
        hosts.add(
          ParsedHost(
            name: currentName,
            hostname: hostname,
            port: port,
            user: user,
            identityFiles: List.unmodifiable(identityFiles),
            sourcePath: canonicalPath,
          ),
        );
      }
    }

    final baseDir = file.parent.path;

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) {
        continue;
      }
      final lower = line.toLowerCase();
      if (lower.startsWith('host ')) {
        commit();
        currentName = line.substring(5).trim();
        hostname = null;
        port = 22;
        user = null;
        identityFiles.clear();
      } else if (lower.startsWith('hostname ')) {
        hostname = line.substring(9).trim();
      } else if (lower.startsWith('port ')) {
        port = int.tryParse(line.substring(5).trim()) ?? 22;
      } else if (lower.startsWith('user ')) {
        user = line.substring(5).trim();
      } else if (lower.startsWith('identityfile ')) {
        final expanded = _expandPath(line.substring(12).trim(), baseDir);
        if (expanded.isNotEmpty) {
          identityFiles.add(expanded);
        }
      } else if (lower.startsWith('include ')) {
        commit();
        final includeTargets = _resolveIncludePaths(
          line.substring(7).trim(),
          baseDir,
        );
        for (final includePath in includeTargets) {
          hosts.addAll(
            await collectEntries(
              includePath,
              visited,
              blockedPaths: blockedPaths,
            ),
          );
        }
      }
    }

    commit();
    return hosts;
  }

  Future<String> _canonicalize(File file) async {
    try {
      return await file.resolveSymbolicLinks();
    } catch (error, stackTrace) {
      AppLogger.w(
        'Failed to resolve SSH config path ${file.path}',
        tag: 'SSHConfig',
        error: error,
        stackTrace: stackTrace,
      );
      return file.path;
    }
  }

  List<String> _resolveIncludePaths(String clause, String baseDir) {
    if (clause.isEmpty) {
      return [];
    }
    final targets = <String>[];
    final parts = clause.split(RegExp(r'\s+'));
    for (final rawPart in parts) {
      if (rawPart.isEmpty) continue;
      final expanded = _expandPath(rawPart, baseDir);
      if (_hasGlob(expanded)) {
        targets.addAll(_expandGlob(expanded));
      } else {
        targets.add(expanded);
      }
    }
    return targets;
  }

  String _expandPath(String rawPath, String baseDir) {
    var path = rawPath.trim();
    if (path.startsWith('~')) {
      final home = Platform.environment['HOME'];
      if (home != null) {
        path = path.replaceFirst('~', home);
      }
    } else if (!path.startsWith('/') && !path.contains(':')) {
      path = '$baseDir/$path';
    }
    return path;
  }

  bool _hasGlob(String path) => path.contains('*') || path.contains('?');

  List<String> _expandGlob(String patternPath) {
    final separatorIndex = patternPath.lastIndexOf(RegExp(r'[\\/]'));
    final directoryPath = separatorIndex == -1
        ? '.'
        : patternPath.substring(0, separatorIndex);
    final filePattern = separatorIndex == -1
        ? patternPath
        : patternPath.substring(separatorIndex + 1);
    final directory = Directory(directoryPath);
    if (!directory.existsSync()) {
      return [];
    }
    final regex = _globToRegExp(filePattern);
    return directory
        .listSync()
        .whereType<File>()
        .where((file) => regex.hasMatch(file.uri.pathSegments.last))
        .map((file) => file.path)
        .toList();
  }

  RegExp _globToRegExp(String pattern) {
    final buffer = StringBuffer('^');
    for (final rune in pattern.runes) {
      final char = String.fromCharCode(rune);
      switch (char) {
        case '*':
          buffer.write('.*');
          break;
        case '?':
          buffer.write('.');
          break;
        case '.':
        case '(':
        case ')':
        case '+':
        case '|':
        case '^':
        case r'$':
        case '[':
        case ']':
        case '{':
        case '}':
        case '\\':
          buffer.write('\\$char');
          break;
        default:
          buffer.write(char);
      }
    }
    buffer.write(r'$');
    return RegExp(buffer.toString());
  }
}

class ParsedHost {
  const ParsedHost({
    required this.name,
    required this.hostname,
    required this.port,
    this.user,
    this.identityFiles = const [],
    required this.sourcePath,
  });

  final String name;
  final String hostname;
  final int port;
  final String? user;
  final List<String> identityFiles;
  final String sourcePath; // The actual config file path this host came from
}

class SshConfigService {
  SshConfigService({
    SshConfigSource? source,
    SshConfigParser? parser,
    List<CustomSshHost> customHosts = const [],
    List<String> additionalEntryPoints = const [],
    List<String> disabledEntryPoints = const [],
  }) : _source = source ?? SshConfigSource.forPlatform(),
       _parser = parser ?? const SshConfigParser(),
       _customHosts = customHosts,
       _additionalEntryPoints = additionalEntryPoints,
       _disabledEntryPoints = disabledEntryPoints;

  final SshConfigSource _source;
  final SshConfigParser _parser;
  final List<CustomSshHost> _customHosts;
  final List<String> _additionalEntryPoints;
  final List<String> _disabledEntryPoints;

  Future<List<SshHost>> loadHosts() async {
    final visited = <String>{};
    final hostsWithSource = <({ParsedHost host, String source})>[];
    final entryPoints = <String>{
      ...await _source.entryPoints(),
      ..._additionalEntryPoints,
    };
    final blocked = await _canonicalizeAll(_disabledEntryPoints);

    for (final entryPoint in entryPoints) {
      final hosts = await _parser.collectEntries(
        entryPoint,
        visited,
        blockedPaths: blocked,
      );
      for (final host in hosts) {
        // Use the actual source path from the parsed host (which tracks includes)
        hostsWithSource.add((host: host, source: host.sourcePath));
      }
    }

    // Add custom hosts
    for (final customHost in _customHosts) {
      hostsWithSource.add((
        host: ParsedHost(
          name: customHost.name,
          hostname: customHost.hostname,
          port: customHost.port,
          user: customHost.user,
          identityFiles: customHost.identityFile != null
              ? [customHost.identityFile!]
              : [],
          sourcePath: 'custom',
        ),
        source: 'custom',
      ));
    }

    return Future.wait(
      hostsWithSource.map((entry) async {
        final online = await _checkAvailability(
          entry.host.hostname,
          entry.host.port,
        );
        return SshHost(
          name: entry.host.name,
          hostname: entry.host.hostname,
          port: entry.host.port,
          available: online,
          user: entry.host.user,
          identityFiles: entry.host.identityFiles,
          source: entry.source,
        );
      }),
    );
  }

  Future<bool> _checkAvailability(String host, int port) async {
    try {
      final socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 2),
      );
      socket.destroy();
      return true;
    } catch (error) {
      AppLogger.w(
        'Failed to check SSH availability for $host:$port',
        tag: 'SSH',
        error: error,
      );
      return false;
    }
  }

  Future<Set<String>> _canonicalizeAll(List<String> paths) async {
    final resolved = <String>{};
    for (final path in paths) {
      try {
        final file = File(path);
        final canonical = await file.resolveSymbolicLinks();
        resolved.add(canonical);
      } catch (error, stackTrace) {
        AppLogger.w(
          'Failed to canonicalize SSH config path $path',
          tag: 'SSHConfig',
          error: error,
          stackTrace: stackTrace,
        );
        resolved.add(path);
      }
    }
    return resolved;
  }
}
