import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cwatch/model/features/docker/services/docker_cli_executor.dart';
import 'package:cwatch/model/features/docker/services/docker_cli_failure.dart';
import 'package:cwatch/model/features/docker/services/docker_cli_parsers.dart';
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
    DockerCliParsers? parsers,
  }) : _executor = executor ?? DockerCliExecutor(processRunner: processRunner),
       _parsers = parsers ?? const DockerCliParsers();

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
  final DockerCliParsers _parsers;

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
      return _parsers.parseContexts(output);
    } on DockerCliFailure catch (error, stackTrace) {
      _logDockerCliFailure('listing contexts', error, stackTrace);
      throw _mapDockerCliFailure(error, timeoutLabel: 'listing Docker contexts');
    }
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
      return _parsers.parseContainers(output);
    } on DockerCliFailure catch (error, stackTrace) {
      _logDockerCliFailure('listing containers', error, stackTrace);
      throw _mapDockerCliFailure(
        error,
        timeoutLabel: 'listing containers',
      );
    }
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
      return _parsers.parseImages(output);
    } on DockerCliFailure catch (error, stackTrace) {
      _logDockerCliFailure('listing images', error, stackTrace);
      throw _mapDockerCliFailure(error, timeoutLabel: 'listing images');
    }
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
    return _parsers.parseNetworks(output);
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
    var volumes = _parsers.parseVolumes(output);
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
    return _parsers.parseDockerDate(cleaned);
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
    return _parsers.parseStats(output);
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
      final memTotalBytes = _parsers.parseMemoryBytes(memTotalStr);
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
        final memBytes = _parsers.parseMemoryBytes(memUsageStr);
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
      return _parsers.parseVolumeSizes(output);
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
