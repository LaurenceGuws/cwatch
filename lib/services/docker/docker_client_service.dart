import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../models/docker_context.dart';
import '../../models/docker_container.dart';
import '../../models/docker_image.dart';
import '../../models/docker_network.dart';
import '../../models/docker_volume.dart';
import '../logging/app_logger.dart';

class DockerClientService {
  const DockerClientService({
    this.processRunner = Process.run,
  });

  final Future<ProcessResult> Function(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool runInShell,
    Encoding? stdoutEncoding,
    Encoding? stderrEncoding,
  }) processRunner;

  Future<List<DockerContext>> listContexts({
    Duration timeout = const Duration(seconds: 6),
  }) async {
    _log('Listing contexts');
    try {
      final result = await processRunner(
        'docker',
        ['context', 'ls', '--format', '{{json .}}'],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
        runInShell: false,
      ).timeout(timeout);

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
    } on ProcessException catch (error) {
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
      } catch (_) {
        // Skip malformed lines
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
      final result = await processRunner(
        'docker',
        args,
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
        runInShell: false,
      ).timeout(timeout);

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
    } on ProcessException catch (error) {
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
      } catch (_) {
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
    Map<String, String> _labelMap(String raw) {
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
    final labels =
        labelsRaw.isEmpty ? const <String, String>{} : _labelMap(labelsRaw);
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
    );
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
      final result = await processRunner(
        'docker',
        args,
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
        runInShell: false,
      ).timeout(timeout);

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
    } on ProcessException catch (error) {
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
      } catch (_) {
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
    final result = await processRunner(
      'docker',
      args,
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
      runInShell: false,
    ).timeout(timeout);
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
      } catch (_) {
        continue;
      }
    }
    return items;
  }

  Future<List<DockerVolume>> listVolumes({
    String? context,
    Duration timeout = const Duration(seconds: 6),
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
    final result = await processRunner(
      'docker',
      args,
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
      runInShell: false,
    ).timeout(timeout);
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
    return _parseVolumes(output);
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
            ),
          );
        }
      } catch (_) {
        continue;
      }
    }
    return items;
  }

  void _log(String message) {
    AppLogger.d(message, tag: 'ProcessDocker');
  }
}
