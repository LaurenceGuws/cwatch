import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cwatch/model/features/docker/services/docker_cli_executor.dart';
import 'package:cwatch/model/features/docker/services/docker_cli_failure.dart';
import 'package:cwatch/model/models/docker_context.dart';
import 'package:cwatch/model/models/docker_container.dart';
import 'package:cwatch/model/models/docker_container_stat.dart';
import 'package:cwatch/model/models/docker_image.dart';
import 'package:cwatch/model/models/docker_network.dart';
import 'package:cwatch/model/models/docker_volume.dart';
import 'package:cwatch/model/services_infra/logging/app_logger.dart';

class DockerClientService {
  DockerClientService({
    this.processRunner = Process.run,
    DockerCliExecutor? executor,
  }) : _executor = executor ?? DockerCliExecutor(processRunner: processRunner);

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
  final DockerCliExecutor _executor;

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
    } on DockerCliFailure catch (error, stackTrace) {
      _logDockerCliFailure('listing contexts', error, stackTrace);
      throw _mapDockerCliFailure(error, timeoutLabel: 'listing Docker contexts');
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
        AppLogger().warn(
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
        contextLabel: dockerHost ?? context,
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
    } on DockerCliFailure catch (error, stackTrace) {
      _logDockerCliFailure('listing containers', error, stackTrace);
      throw _mapDockerCliFailure(
        error,
        timeoutLabel: 'listing containers',
      );
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
        AppLogger().warn(
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
    String? context,
    Duration timeout = const Duration(seconds: 6),
  }) async {
    final args = <String>[
      if (context != null && context.trim().isNotEmpty) ...[
        '--context',
        context.trim(),
      ],
      'exec',
      '-i',
      containerId,
      'sh',
      '-c',
      command,
    ];
    try {
      final result = await _runDockerProcess(
        args,
        timeout: timeout,
        operation: 'exec',
        contextLabel: context,
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
    } on DockerCliFailure catch (error, stackTrace) {
      _logDockerCliFailure('running exec', error, stackTrace);
      throw _mapDockerCliFailure(error, timeoutLabel: 'running docker exec');
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
        contextLabel: context,
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
    } on DockerCliFailure catch (error, stackTrace) {
      _logDockerCliFailure('listing images', error, stackTrace);
      throw _mapDockerCliFailure(error, timeoutLabel: 'listing images');
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
        AppLogger().warn(
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
      contextLabel: context,
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
        AppLogger().warn(
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
      contextLabel: context,
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
      contextLabel: context,
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

  Future<void> removeImage({
    required String imageId,
    String? context,
    bool force = false,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final args = ['rmi'];
    if (force) args.add('-f');
    args.add(imageId);
    await _runDockerCommand(
      args,
      context: context,
      op: 'remove image',
      timeout: timeout,
    );
  }

  Future<void> pruneImages({
    String? context,
    bool all = false,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final args = ['image', 'prune', '-f'];
    if (all) args.add('-a');
    await _runDockerCommand(
      args,
      context: context,
      op: 'prune images',
      timeout: timeout,
    );
  }

  Future<void> pullImage({
    required String imageName,
    String? context,
    Duration timeout = const Duration(minutes: 10),
  }) async {
    await _runDockerCommand(
      ['pull', imageName],
      context: context,
      op: 'pull image',
      timeout: timeout,
    );
  }

  Future<void> tagImage({
    required String sourceImage,
    required String targetImage,
    String? context,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    await _runDockerCommand(
      ['tag', sourceImage, targetImage],
      context: context,
      op: 'tag image',
      timeout: timeout,
    );
  }

  Future<void> pushImage({
    required String imageName,
    String? context,
    Duration timeout = const Duration(minutes: 10),
  }) async {
    await _runDockerCommand(
      ['push', imageName],
      context: context,
      op: 'push image',
      timeout: timeout,
    );
  }

  Future<String> inspectImage({
    required String imageId,
    String? context,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final args = <String>[
      if (context != null && context.trim().isNotEmpty) ...[
        '--context',
        context.trim(),
      ],
      'inspect',
      imageId,
    ];
    final result = await _runDockerProcess(
      args,
      timeout: timeout,
      operation: 'inspect image',
      contextLabel: context,
    );
    if (result.exitCode != 0) {
      final stderr = (result.stderr as String?)?.trim();
      throw Exception(
        stderr?.isNotEmpty == true
            ? stderr
            : 'docker inspect failed with exit code ${result.exitCode}',
      );
    }
    return (result.stdout as String?) ?? '';
  }

  Future<String> imageHistory({
    required String imageId,
    String? context,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final args = <String>[
      if (context != null && context.trim().isNotEmpty) ...[
        '--context',
        context.trim(),
      ],
      'history',
      '--no-trunc',
      imageId,
    ];
    final result = await _runDockerProcess(
      args,
      timeout: timeout,
      operation: 'image history',
      contextLabel: context,
    );
    if (result.exitCode != 0) {
      final stderr = (result.stderr as String?)?.trim();
      throw Exception(
        stderr?.isNotEmpty == true
            ? stderr
            : 'docker history failed with exit code ${result.exitCode}',
      );
    }
    return (result.stdout as String?) ?? '';
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

  /// Get aggregate CPU and RAM usage for a Docker context.
  /// Returns a map with 'cpu' (percentage as double) and 'ram' (percentage as double).
  /// Returns null if stats cannot be retrieved.
  Future<Map<String, double>?> getAggregateStats({
    String? context,
    Duration timeout = const Duration(seconds: 6),
  }) async {
    _log('Getting aggregate stats context=$context');
    try {
      // First get total memory
      final infoArgs = <String>[
        if (context != null && context.trim().isNotEmpty) ...[
          '--context',
          context.trim(),
        ],
        'info',
        '--format',
        '{{.MemTotal}}',
      ];
      final infoResult = await _runDockerProcess(
        infoArgs,
        timeout: timeout,
        operation: 'get docker info',
      );
      if (infoResult.exitCode != 0) {
        return null;
      }
      final memTotalStr = (infoResult.stdout as String?)?.trim() ?? '';
      if (memTotalStr.isEmpty) {
        return null;
      }

      // Parse total memory (e.g., "15.5GiB" -> bytes)
      final memTotalBytes = _parseMemoryBytes(memTotalStr);
      if (memTotalBytes == null || memTotalBytes == 0) {
        return null;
      }

      // Get container stats
      final statsArgs = <String>[
        if (context != null && context.trim().isNotEmpty) ...[
          '--context',
          context.trim(),
        ],
        'stats',
        '--no-stream',
        '--format',
        '{{.CPUPerc}} {{.MemUsage}}',
      ];
      final statsResult = await _runDockerProcess(
        statsArgs,
        timeout: timeout,
        operation: 'get docker stats',
      );
      if (statsResult.exitCode != 0) {
        final stderr = (statsResult.stderr as String?)?.trim();
        _log('docker stats failed: exitCode=${statsResult.exitCode}, stderr=$stderr');
        return null;
      }

      final output = (statsResult.stdout as String?) ?? '';
      _log('docker stats output length=${output.length}');
      if (output.trim().isEmpty) {
        // No containers running
        return {'cpu': 0.0, 'ram': 0.0};
      }

      // Parse stats: sum CPU percentages, sum memory usage
      double totalCpu = 0.0;
      int totalMemBytes = 0;

      for (final line in const LineSplitter().convert(output)) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;

        final parts = trimmed.split(RegExp(r'\s+'));
        if (parts.length < 2) continue;

        // Parse CPU percentage (remove % sign)
        final cpuStr = parts[0].replaceAll('%', '').trim();
        final cpu = double.tryParse(cpuStr) ?? 0.0;
        totalCpu += cpu;

        // Parse memory usage (e.g., "1.2GiB / 15.5GiB" -> use first part)
        final memUsageStr = parts[1];
        final memBytes = _parseMemoryBytes(memUsageStr);
        if (memBytes != null) {
          totalMemBytes += memBytes;
        }
      }

      final ramPercent = (totalMemBytes / memTotalBytes) * 100.0;

      return {
        'cpu': totalCpu,
        'ram': ramPercent,
      };
    } catch (error, stackTrace) {
      AppLogger().warn(
        'Failed to get aggregate stats',
        tag: 'Docker',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Parse memory string (e.g., "15.5GiB", "1.2MiB", "512KiB") to bytes.
  int? _parseMemoryBytes(String memoryStr) {
    final trimmed = memoryStr.trim();
    if (trimmed.isEmpty) return null;

    // Handle formats like "1.2GiB / 15.5GiB" - take first part
    final parts = trimmed.split('/');
    final memStr = parts[0].trim();

    // Extract number and unit
    final match = RegExp(r'^([\d.]+)\s*(GiB|MiB|KiB|B)$', caseSensitive: false)
        .firstMatch(memStr);
    if (match == null) return null;

    final value = double.tryParse(match.group(1) ?? '');
    if (value == null) return null;

    final unit = (match.group(2) ?? '').toLowerCase();
    switch (unit) {
      case 'gib':
        return (value * 1024 * 1024 * 1024).round();
      case 'mib':
        return (value * 1024 * 1024).round();
      case 'kib':
        return (value * 1024).round();
      case 'b':
        return value.round();
      default:
        return null;
    }
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
        AppLogger().warn(
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
        AppLogger().warn(
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
    AppLogger().debug(message, tag: 'ProcessDocker');
  }

  Future<ProcessResult> _runDockerProcess(
    List<String> args, {
    required Duration timeout,
    String operation = 'run',
    String? contextLabel,
  }) async {
    return _executor.run(
      args,
      timeout: timeout,
      operation: operation,
      contextLabel: contextLabel,
    );
  }

  void _logDockerCliFailure(
    String action,
    DockerCliFailure error,
    StackTrace stackTrace,
  ) {
    if (error.kind == DockerCliFailureKind.unavailable) {
      AppLogger().warn(
        'Docker CLI not available while $action',
        tag: 'Docker',
        error: error.cause ?? error,
        stackTrace: stackTrace,
      );
    }
  }

  Exception _mapDockerCliFailure(
    DockerCliFailure error, {
    required String timeoutLabel,
  }) {
    switch (error.kind) {
      case DockerCliFailureKind.unavailable:
        return Exception('Docker CLI not available: ${error.message}');
      case DockerCliFailureKind.timeout:
        return Exception('Timed out while $timeoutLabel.');
      case DockerCliFailureKind.processError:
        return Exception(error.message);
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
        contextLabel: context,
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
          AppLogger().warn(
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
      AppLogger().warn(
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
      contextLabel: context,
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
