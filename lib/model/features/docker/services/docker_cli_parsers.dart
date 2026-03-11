import 'dart:convert';

import 'package:cwatch/model/models/docker_container.dart';
import 'package:cwatch/model/models/docker_container_stat.dart';
import 'package:cwatch/model/models/docker_context.dart';
import 'package:cwatch/model/models/docker_image.dart';
import 'package:cwatch/model/models/docker_network.dart';
import 'package:cwatch/model/models/docker_volume.dart';
import 'package:cwatch/model/services_infra/logging/app_logger.dart';

class DockerCliParsers {
  const DockerCliParsers();

  List<DockerContext> parseContexts(String output) {
    return _parseJsonLines(
      output,
      action: 'context',
      decode: (map) => DockerContext(
        name: _readString(map, 'Name'),
        dockerEndpoint: _readString(map, 'DockerEndpoint'),
        description: _optionalString(map, 'Description'),
        kubernetesEndpoint: _optionalString(map, 'KubernetesEndpoint'),
        orchestrator: _optionalString(map, 'Orchestrator'),
        current: _readCurrent(map['Current']),
      ),
    );
  }

  List<DockerContainer> parseContainers(String output) {
    return _parseJsonLines(
      output,
      action: 'container',
      decode: (map) {
        final labelsRaw = _readString(map, 'Labels');
        final labels = labelsRaw.isEmpty
            ? const <String, String>{}
            : _labelMap(labelsRaw);
        return DockerContainer(
          id: _readString(map, 'ID'),
          name: _readString(map, 'Names'),
          image: _readString(map, 'Image'),
          state: _readString(map, 'State'),
          status: _readString(map, 'Status'),
          ports: _readString(map, 'Ports'),
          command: _optionalString(map, 'Command'),
          createdAt: _optionalString(map, 'RunningFor'),
          composeProject: labels['com.docker.compose.project'],
          composeService: labels['com.docker.compose.service'],
          startedAt: parseDockerDate(_readString(map, 'StartedAt')),
        );
      },
    );
  }

  List<DockerImage> parseImages(String output) {
    return _parseJsonLines(
      output,
      action: 'image',
      decode: (map) => DockerImage(
        id: _readString(map, 'ID'),
        repository: _readString(map, 'Repository'),
        tag: _readString(map, 'Tag'),
        size: _readString(map, 'Size'),
        createdSince: _optionalString(map, 'CreatedSince'),
      ),
    );
  }

  List<DockerNetwork> parseNetworks(String output) {
    return _parseJsonLines(
      output,
      action: 'network',
      decode: (map) => DockerNetwork(
        id: _readString(map, 'ID'),
        name: _readString(map, 'Name'),
        driver: _readString(map, 'Driver'),
        scope: _readString(map, 'Scope'),
      ),
    );
  }

  List<DockerVolume> parseVolumes(String output) {
    return _parseJsonLines(
      output,
      action: 'volume',
      decode: (map) => DockerVolume(
        name: _readString(map, 'Name'),
        driver: _readString(map, 'Driver'),
        mountpoint: _optionalString(map, 'Mountpoint'),
        scope: _optionalString(map, 'Scope'),
        size: volumeSizeOrNull(_optionalString(map, 'Size')),
      ),
    );
  }

  List<DockerContainerStat> parseStats(String output) {
    return _parseJsonLines(
      output,
      action: 'stats',
      decode: (map) => DockerContainerStat(
        id: _readString(map, 'Container'),
        name: _readString(map, 'Name'),
        cpu: _readString(map, 'CPUPerc'),
        memUsage: _readString(map, 'MemUsage'),
        memPercent: _readString(map, 'MemPerc'),
        netIO: _readString(map, 'NetIO'),
        blockIO: _readString(map, 'BlockIO'),
        pids: _readString(map, 'PIDs'),
      ),
    );
  }

  Map<String, String> parseVolumeSizes(String output) {
    final map = <String, String>{};
    for (final decoded in _decodeJsonLines(output, action: 'volume size')) {
      final type = _optionalString(decoded, 'Type');
      if (type?.toLowerCase() != 'volume') {
        continue;
      }
      final name = _optionalString(decoded, 'Name');
      final size = volumeSizeOrNull(_optionalString(decoded, 'Size'));
      if (name != null && name.isNotEmpty && size != null) {
        map[name] = size;
      }
    }
    return map;
  }

  int? parseMemoryBytes(String memoryStr) {
    final trimmed = memoryStr.trim();
    if (trimmed.isEmpty) return null;

    final parts = trimmed.split('/');
    final memStr = parts[0].trim();
    final match = RegExp(
      r'^([\d.]+)\s*(GiB|MiB|KiB|B)$',
      caseSensitive: false,
    ).firstMatch(memStr);
    if (match == null) return null;

    final value = double.tryParse(match.group(1) ?? '');
    if (value == null) return null;

    switch ((match.group(2) ?? '').toLowerCase()) {
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

  DateTime? parseDockerDate(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    final cleaned = value
        .replaceAll(' +0000 UTC', 'Z')
        .replaceAll(RegExp(r' [A-Z]{3}$'), '')
        .replaceFirst(' ', 'T');
    return DateTime.tryParse(cleaned);
  }

  String? volumeSizeOrNull(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty || value.toUpperCase() == 'N/A') return null;
    return value;
  }

  List<T> _parseJsonLines<T>(
    String output, {
    required String action,
    required T Function(Map<String, dynamic> map) decode,
  }) {
    final items = <T>[];
    for (final decoded in _decodeJsonLines(output, action: action)) {
      items.add(decode(decoded));
    }
    return items;
  }

  Iterable<Map<String, dynamic>> _decodeJsonLines(
    String output, {
    required String action,
  }) sync* {
    for (final line in const LineSplitter().convert(output)) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map<String, dynamic>) {
          yield decoded;
        }
      } catch (error, stackTrace) {
        AppLogger().warn(
          'Failed to parse docker $action line',
          tag: 'Docker',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
  }

  String _readString(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is String) return value.trim();
    return '';
  }

  String? _optionalString(Map<String, dynamic> map, String key) {
    final value = _readString(map, key);
    return value.isEmpty ? null : value;
  }

  bool _readCurrent(Object? value) {
    if (value is bool) return value;
    if (value is String) {
      final trimmed = value.trim();
      return trimmed == '*' || trimmed.toLowerCase() == 'true';
    }
    return false;
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
}
