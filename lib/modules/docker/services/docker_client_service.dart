import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cwatch/models/docker_context.dart';
import 'package:cwatch/models/docker_container.dart';
import 'package:cwatch/models/docker_container_stat.dart';
import 'package:cwatch/models/docker_image.dart';
import 'package:cwatch/models/docker_network.dart';
import 'package:cwatch/models/docker_volume.dart';
import 'package:cwatch/services/logging/app_logger.dart';

class DockerClientService {
  const DockerClientService({this.processRunner = Process.run});

  final Future<ProcessResult> Function(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool runInShell,
    Encoding? stdoutEncoding,
    Encoding? stderrEncoding,
  })
  processRunner;

  Future<List<DockerContext>> listContexts({
    Duration timeout = const Duration(seconds: 6),
  }) async {
    _log('Listing contexts');
    try {
      final result = await _runDockerProcess(
        ['context', 'ls', '--format', '{{json .}}'],
        timeout: timeout,
        operation: 'list contexts',
      );

      if (result.exitCode != 0) {
        final stderr = (result.stderr as String?)?.trim();
        throw Exception(
          stderr?.isNotEmpty == true
              ? stderr
              : 'docker context ls failed with exit code ${result.exitCode}',
        );
      }

      final output = (result.stdout as String?) ?? '';
      _log('Contexts output length=${output.length}');
      return _parseJsonLines(output);
    } on ProcessException catch (error, stackTrace) {
      AppLogger.w(
        'Docker CLI not available while listing contexts',
        tag: 'Docker',
        error: error,
        stackTrace: stackTrace,
      );
      throw Exception('Docker CLI not available: ${error.message}');
    } on TimeoutException {
      throw Exception('Timed out while listing Docker contexts.');
    }
  }

  List<DockerContext> _parseJsonLines(String output) {
    final contexts = <DockerContext>[];
    for (final line in const LineSplitter().convert(output)) {
      if (line.trim().isEmpty) {
        continue;
      }
      try {
        final decoded = jsonDecode(line);
        if (decoded is Map<String, dynamic>) {
          contexts.add(_fromMap(decoded));
        }
      } catch (error, stackTrace) {
        AppLogger.w(
          'Failed to parse docker context line',
          tag: 'Docker',
          error: error,
          stackTrace: stackTrace,
        );
        continue;
      }
    }
    return contexts;
  }

  DockerContext _fromMap(Map<String, dynamic> map) {
    String readString(String key) {
      final value = map[key];
      if (value is String) {
        return value.trim();
      }
      return '';
    }

    bool readCurrent() {
      final value = map['Current'];
      if (value is bool) return value;
      if (value is String) {
        final trimmed = value.trim();
        return trimmed == '*' || trimmed.toLowerCase() == 'true';
      }
      return false;
    }

    return DockerContext(
      name: readString('Name'),
      dockerEndpoint: readString('DockerEndpoint'),
      description: readString('Description').isEmpty
          ? null
          : readString('Description'),
      kubernetesEndpoint: readString('KubernetesEndpoint').isEmpty
          ? null
          : readString('KubernetesEndpoint'),
      orchestrator: readString('Orchestrator').isEmpty
          ? null
          : readString('Orchestrator'),
      current: readCurrent(),
    );
  }

  Future<List<DockerContainer>> listContainers({
    String? context,
    String? dockerHost,
    bool includeAll = true,
    Duration timeout = const Duration(seconds: 6),
  }) async {
    _log('Listing containers context=$context host=$dockerHost');
    final args = <String>[
      if (context != null && context.trim().isNotEmpty) ...[
        '--context',
        context.trim(),
      ] else if (dockerHost != null && dockerHost.trim().isNotEmpty) ...[
        '--host',
        dockerHost.trim(),
      ],
      'ps',
      if (includeAll) '-a',
      '--format',
      '{{json .}}',
    ];

    try {
      final result = await _runDockerProcess(
        args,
        timeout: timeout,
        operation: 'list containers',
      );

      if (result.exitCode != 0) {
        final stderr = (result.stderr as String?)?.trim();
        throw Exception(
          stderr?.isNotEmpty == true
              ? stderr
              : 'docker ps failed with exit code ${result.exitCode}',
        );
      }

      final output = (result.stdout as String?) ?? '';
      _log('Containers output length=${output.length}');
      return _parseContainerLines(output);
    } on ProcessException catch (error, stackTrace) {
      AppLogger.w(
        'Docker CLI not available while listing containers',
        tag: 'Docker',
        error: error,
        stackTrace: stackTrace,
      );
      throw Exception('Docker CLI not available: ${error.message}');
    } on TimeoutException {
      throw Exception('Timed out while listing containers.');
    }
  }

  List<DockerContainer> _parseContainerLines(String output) {
    final items = <DockerContainer>[];
    for (final line in const LineSplitter().convert(output)) {
      if (line.trim().isEmpty) continue;
      try {
        final decoded = jsonDecode(line);
        if (decoded is Map<String, dynamic>) {
          items.add(_containerFromMap(decoded));
        }
      } catch (error, stackTrace) {
        AppLogger.w(
          'Failed to parse docker container line',
          tag: 'Docker',
          error: error,
          stackTrace: stackTrace,
        );
        continue;
      }
    }
    return items;
  }

  DockerContainer _containerFromMap(Map<String, dynamic> map) {
    String read(String key) {
      final value = map[key];
      if (value is String) return value.trim();
      return '';
    }

    Map<String, String> labelMap(String raw) {
      final entries = <String, String>{};
      for (final part in raw.split(',')) {
        final kv = part.split('=');
        if (kv.length == 2) {
          entries[kv[0].trim()] = kv[1].trim();
        }
      }
      return entries;
    }

    final labelsRaw = read('Labels');
    final labels = labelsRaw.isEmpty
        ? const <String, String>{}
        : labelMap(labelsRaw);
    return DockerContainer(
      id: read('ID'),
      name: read('Names'),
      image: read('Image'),
      state: read('State'),
      status: read('Status'),
      ports: read('Ports'),
      command: read('Command').isEmpty ? null : read('Command'),
      createdAt: read('RunningFor').isEmpty ? null : read('RunningFor'),
      composeProject: labels['com.docker.compose.project'],
      composeService: labels['com.docker.compose.service'],
      startedAt: _parseDockerDate(read('StartedAt')),
    );
  }

  Future<String> execInContainer(
    String containerId,
    String command, {
    Duration timeout = const Duration(seconds: 6),
  }) async {
    final args = ['exec', '-i', containerId, 'sh', '-c', command];
    try {
      final result = await _runDockerProcess(
        args,
        timeout: timeout,
        operation: 'exec',
      );

      if (result.exitCode != 0) {
        final stderr = (result.stderr as String?)?.trim();
        throw Exception(
          stderr?.isNotEmpty == true
              ? stderr
              : 'docker exec failed with exit code ${result.exitCode}',
        );
      }

      return (result.stdout as String?) ?? '';
    } on ProcessException catch (error, stackTrace) {
      AppLogger.w(
        'Docker CLI not available while running exec',
        tag: 'Docker',
        error: error,
        stackTrace: stackTrace,
      );
      throw Exception('Docker CLI not available: ${error.message}');
    } on TimeoutException {
      throw Exception('Timed out while running docker exec.');
    }
  }

  Future<List<DockerImage>> listImages({
    String? context,
    bool danglingOnly = false,
    Duration timeout = const Duration(seconds: 6),
  }) async {
    _log('Listing images context=$context dangling=$danglingOnly');
    final args = <String>[
      if (context != null && context.trim().isNotEmpty) ...[
        '--context',
        context.trim(),
      ],
      'images',
      '--format',
      '{{json .}}',
      if (danglingOnly) '--filter=dangling=true',
    ];

    try {
      final result = await _runDockerProcess(
        args,
        timeout: timeout,
        operation: 'list images',
      );

      if (result.exitCode != 0) {
        final stderr = (result.stderr as String?)?.trim();
        throw Exception(
          stderr?.isNotEmpty == true
              ? stderr
              : 'docker images failed with exit code ${result.exitCode}',
        );
      }

      final output = (result.stdout as String?) ?? '';
      _log('Images output length=${output.length}');
      return _parseImageLines(output);
    } on ProcessException catch (error, stackTrace) {
      AppLogger.w(
        'Docker CLI not available while listing images',
        tag: 'Docker',
        error: error,
        stackTrace: stackTrace,
      );
      throw Exception('Docker CLI not available: ${error.message}');
    } on TimeoutException {
      throw Exception('Timed out while listing images.');
    }
  }

  List<DockerImage> _parseImageLines(String output) {
    final items = <DockerImage>[];
    for (final line in const LineSplitter().convert(output)) {
      if (line.trim().isEmpty) continue;
      try {
        final decoded = jsonDecode(line);
        if (decoded is Map<String, dynamic>) {
          items.add(_imageFromMap(decoded));
        }
      } catch (error, stackTrace) {
        AppLogger.w(
          'Failed to parse docker image line',
          tag: 'Docker',
          error: error,
          stackTrace: stackTrace,
        );
        continue;
      }
    }
    return items;
  }

  DockerImage _imageFromMap(Map<String, dynamic> map) {
    String read(String key) {
      final value = map[key];
      if (value is String) return value.trim();
      return '';
    }

    return DockerImage(
      id: read('ID'),
      repository: read('Repository'),
      tag: read('Tag'),
      size: read('Size'),
      createdSince: read('CreatedSince').isEmpty ? null : read('CreatedSince'),
    );
  }

  Future<List<DockerNetwork>> listNetworks({
    String? context,
    Duration timeout = const Duration(seconds: 6),
  }) async {
    _log('Listing networks context=$context');
    final args = <String>[
      if (context != null && context.trim().isNotEmpty) ...[
        '--context',
        context.trim(),
      ],
      'network',
      'ls',
      '--format',
      '{{json .}}',
    ];
    final result = await _runDockerProcess(
      args,
      timeout: timeout,
      operation: 'list networks',
    );
    if (result.exitCode != 0) {
      final stderr = (result.stderr as String?)?.trim();
      throw Exception(
        stderr?.isNotEmpty == true
            ? stderr
            : 'docker network ls failed with exit code ${result.exitCode}',
      );
    }
    final output = (result.stdout as String?) ?? '';
    _log('Networks output length=${output.length}');
    return _parseNetworks(output);
  }

  List<DockerNetwork> _parseNetworks(String output) {
    final items = <DockerNetwork>[];
    for (final line in const LineSplitter().convert(output)) {
      if (line.trim().isEmpty) continue;
      try {
        final decoded = jsonDecode(line);
        if (decoded is Map<String, dynamic>) {
          items.add(
            DockerNetwork(
              id: (decoded['ID'] as String?)?.trim() ?? '',
              name: (decoded['Name'] as String?)?.trim() ?? '',
              driver: (decoded['Driver'] as String?)?.trim() ?? '',
              scope: (decoded['Scope'] as String?)?.trim() ?? '',
            ),
          );
        }
      } catch (error, stackTrace) {
        AppLogger.w(
          'Failed to parse docker network line',
          tag: 'Docker',
          error: error,
          stackTrace: stackTrace,
        );
        continue;
      }
    }
    return items;
  }

  Future<List<DockerVolume>> listVolumes({
    String? context,
    Duration timeout = const Duration(seconds: 6),
    bool includeSizes = true,
  }) async {
    _log('Listing volumes context=$context');
    final args = <String>[
      if (context != null && context.trim().isNotEmpty) ...[
        '--context',
        context.trim(),
      ],
      'volume',
      'ls',
      '--format',
      '{{json .}}',
    ];
    final result = await _runDockerProcess(
      args,
      timeout: timeout,
      operation: 'list volumes',
    );
    if (result.exitCode != 0) {
      final stderr = (result.stderr as String?)?.trim();
      throw Exception(
        stderr?.isNotEmpty == true
            ? stderr
            : 'docker volume ls failed with exit code ${result.exitCode}',
      );
    }
    final output = (result.stdout as String?) ?? '';
    _log('Volumes output length=${output.length}');
    var volumes = _parseVolumes(output);
    if (includeSizes) {
      final sizes = await _fetchVolumeSizes(context: context);
      volumes = _applyVolumeSizes(volumes, sizes);
    }
    return volumes;
  }

  Future<void> startContainer({
    required String id,
    String? context,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    await _runDockerCommand(
      ['start', id],
      context: context,
      op: 'start',
      timeout: timeout,
    );
  }

  Future<void> stopContainer({
    required String id,
    String? context,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    await _runDockerCommand(
      ['stop', id],
      context: context,
      op: 'stop',
      timeout: timeout,
    );
  }

  Future<void> restartContainer({
    required String id,
    String? context,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    await _runDockerCommand(
      ['restart', id],
      context: context,
      op: 'restart',
      timeout: timeout,
    );
  }

  Future<DateTime?> inspectContainerStartTime({
    required String id,
    String? context,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final args = <String>[
      if (context != null && context.trim().isNotEmpty) ...[
        '--context',
        context.trim(),
      ],
      'inspect',
      '-f',
      '{{json .State.StartedAt}}',
      id,
    ];
    _log('Inspecting start time for $id');
    final result = await _runDockerProcess(
      args,
      timeout: timeout,
      operation: 'inspect',
    );
    if (result.exitCode != 0) {
      final stderr = (result.stderr as String?)?.trim();
      throw Exception(
        stderr?.isNotEmpty == true
            ? stderr
            : 'docker inspect failed with exit code ${result.exitCode}',
      );
    }
    final output = ((result.stdout as String?) ?? '').trim();
    if (output.isEmpty) return null;
    final cleaned = output.replaceAll('"', '');
    return _parseDockerDate(cleaned);
  }

  Future<void> removeContainer({
    required String id,
    String? context,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    await _runDockerCommand(
      ['rm', '-f', id],
      context: context,
      op: 'remove',
      timeout: timeout,
    );
  }

  Future<void> systemPrune({
    String? context,
    bool includeVolumes = false,
  }) async {
    final args = ['system', 'prune', '-f'];
    if (includeVolumes) args.add('--volumes');
    await _runDockerCommand(args, context: context, op: 'prune');
  }

  Future<List<DockerContainerStat>> listContainerStats({
    String? context,
    Duration timeout = const Duration(seconds: 6),
  }) async {
    _log('Listing container stats context=$context');
    final args = <String>[
      if (context != null && context.trim().isNotEmpty) ...[
        '--context',
        context.trim(),
      ],
      'stats',
      '--no-stream',
      '--format',
      '{{json .}}',
    ];
    final result = await _runDockerProcess(
      args,
      timeout: timeout,
      operation: 'list stats',
    );
    if (result.exitCode != 0) {
      final stderr = (result.stderr as String?)?.trim();
      throw Exception(
        stderr?.isNotEmpty == true
            ? stderr
            : 'docker stats failed with exit code ${result.exitCode}',
      );
    }
    final output = (result.stdout as String?) ?? '';
    return _parseStats(output);
  }

  List<DockerVolume> _parseVolumes(String output) {
    final items = <DockerVolume>[];
    for (final line in const LineSplitter().convert(output)) {
      if (line.trim().isEmpty) continue;
      try {
        final decoded = jsonDecode(line);
        if (decoded is Map<String, dynamic>) {
          items.add(
            DockerVolume(
              name: (decoded['Name'] as String?)?.trim() ?? '',
              driver: (decoded['Driver'] as String?)?.trim() ?? '',
              mountpoint: (decoded['Mountpoint'] as String?)?.trim(),
              scope: (decoded['Scope'] as String?)?.trim(),
              size: _volumeSizeOrNull((decoded['Size'] as String?)?.trim()),
            ),
          );
        }
      } catch (error, stackTrace) {
        AppLogger.w(
          'Failed to parse docker volume line',
          tag: 'Docker',
          error: error,
          stackTrace: stackTrace,
        );
        continue;
      }
    }
    return items;
  }

  List<DockerContainerStat> _parseStats(String output) {
    final items = <DockerContainerStat>[];
    for (final line in const LineSplitter().convert(output)) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map<String, dynamic>) {
          items.add(
            DockerContainerStat(
              id: (decoded['Container'] as String?)?.trim() ?? '',
              name: (decoded['Name'] as String?)?.trim() ?? '',
              cpu: (decoded['CPUPerc'] as String?)?.trim() ?? '',
              memUsage: (decoded['MemUsage'] as String?)?.trim() ?? '',
              memPercent: (decoded['MemPerc'] as String?)?.trim() ?? '',
              netIO: (decoded['NetIO'] as String?)?.trim() ?? '',
              blockIO: (decoded['BlockIO'] as String?)?.trim() ?? '',
              pids: (decoded['PIDs'] as String?)?.trim() ?? '',
            ),
          );
        }
      } catch (error, stackTrace) {
        AppLogger.w(
          'Failed to parse docker stats line',
          tag: 'Docker',
          error: error,
          stackTrace: stackTrace,
        );
        continue;
      }
    }
    return items;
  }

  void _log(String message) {
    AppLogger.d(message, tag: 'ProcessDocker');
  }

  Future<ProcessResult> _runDockerProcess(
    List<String> args, {
    required Duration timeout,
    String operation = 'run',
  }) async {
    final command = 'docker ${args.join(' ')}';
    try {
      final result = await processRunner(
        'docker',
        args,
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
        runInShell: false,
      ).timeout(timeout);
      final stdout = result.stdout?.toString() ?? '';
      final stderr = result.stderr?.toString() ?? '';
      AppLogger.logRemoteCommand(
        source: 'docker',
        operation: operation,
        command: command,
        output: result.exitCode == 0 ? stdout : stderr,
      );
      return result;
    } on TimeoutException {
      AppLogger.logRemoteCommand(
        source: 'docker',
        operation: operation,
        command: command,
        output: 'Timed out after ${timeout.inSeconds}s',
      );
      rethrow;
    } on ProcessException catch (error) {
      AppLogger.logRemoteCommand(
        source: 'docker',
        operation: operation,
        command: command,
        output: 'Process error: ${error.message}',
      );
      rethrow;
    } catch (error) {
      AppLogger.logRemoteCommand(
        source: 'docker',
        operation: operation,
        command: command,
        output: 'Error: $error',
      );
      rethrow;
    }
  }

  String? _volumeSizeOrNull(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty || value.toUpperCase() == 'N/A') return null;
    return value;
  }

  Future<Map<String, String>> _fetchVolumeSizes({
    String? context,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    try {
      final args = <String>[
        if (context != null && context.trim().isNotEmpty) ...[
          '--context',
          context.trim(),
        ],
        'system',
        'df',
        '-v',
        '--format',
        '{{json .}}',
      ];
      final result = await _runDockerProcess(
        args,
        timeout: timeout,
        operation: 'system df',
      );
      if (result.exitCode != 0) {
        return const {};
      }
      final output = (result.stdout as String?) ?? '';
      final map = <String, String>{};
      for (final line in const LineSplitter().convert(output)) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        try {
          final decoded = jsonDecode(trimmed);
          if (decoded is Map<String, dynamic>) {
            final type = (decoded['Type'] as String?)?.trim();
            if (type != null && type.toLowerCase() == 'volume') {
              final name = (decoded['Name'] as String?)?.trim();
              final size = _volumeSizeOrNull(
                (decoded['Size'] as String?)?.trim(),
              );
              if (name != null && name.isNotEmpty && size != null) {
                map[name] = size;
              }
            }
          }
        } catch (error, stackTrace) {
          AppLogger.w(
            'Failed to parse docker volume size entry',
            tag: 'Docker',
            error: error,
            stackTrace: stackTrace,
          );
          continue;
        }
      }
      return map;
    } catch (error, stackTrace) {
      AppLogger.w(
        'Failed to fetch docker volume sizes',
        tag: 'Docker',
        error: error,
        stackTrace: stackTrace,
      );
      return const {};
    }
  }

  List<DockerVolume> _applyVolumeSizes(
    List<DockerVolume> volumes,
    Map<String, String> sizes,
  ) {
    if (sizes.isEmpty) return volumes;
    return volumes
        .map(
          (v) => sizes.containsKey(v.name)
              ? DockerVolume(
                  name: v.name,
                  driver: v.driver,
                  mountpoint: v.mountpoint,
                  scope: v.scope,
                  size: sizes[v.name],
                )
              : v,
        )
        .toList();
  }

  DateTime? _parseDockerDate(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    final cleaned = value
        .replaceAll(' +0000 UTC', 'Z')
        .replaceAll(RegExp(r' [A-Z]{3}$'), '')
        .replaceFirst(' ', 'T');
    return DateTime.tryParse(cleaned);
  }

  Future<void> _runDockerCommand(
    List<String> args, {
    String? context,
    String op = 'cmd',
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final fullArgs = <String>[
      if (context != null && context.trim().isNotEmpty) ...[
        '--context',
        context.trim(),
      ],
      ...args,
    ];
    _log('Running $op: docker ${fullArgs.join(' ')}');
    final result = await _runDockerProcess(
      fullArgs,
      timeout: timeout,
      operation: op,
    );
    if (result.exitCode != 0) {
      final stderr = (result.stderr as String?)?.trim();
      throw Exception(
        stderr?.isNotEmpty == true
            ? stderr
            : 'docker ${args.first} failed with exit code ${result.exitCode}',
      );
    }
    _log('$op completed exit=${result.exitCode}');
  }
}
