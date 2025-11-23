import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../models/docker_context.dart';
import '../../models/docker_container.dart';

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

    return DockerContainer(
      id: read('ID'),
      name: read('Names'),
      image: read('Image'),
      state: read('State'),
      status: read('Status'),
      ports: read('Ports'),
      command: read('Command').isEmpty ? null : read('Command'),
      createdAt: read('RunningFor').isEmpty ? null : read('RunningFor'),
    );
  }
}
