import 'dart:convert';

import 'package:cwatch/models/docker_container.dart';
import 'package:cwatch/models/docker_image.dart';
import 'package:cwatch/models/docker_network.dart';
import 'package:cwatch/models/docker_volume.dart';
import 'package:cwatch/models/ssh_host.dart';
import 'package:cwatch/services/logging/app_logger.dart';
import 'package:cwatch/services/ssh/remote_shell_service.dart';

import 'docker_client_service.dart';

class DockerEngineService {
  const DockerEngineService({required this.docker});

  final DockerClientService docker;

  Future<EngineSnapshot> fetch({
    String? contextName,
    SshHost? remoteHost,
    RemoteShellService? shell,
  }) async {
    if (remoteHost != null && shell != null) {
      final containers = await _loadRemoteContainers(shell, remoteHost);
      final images = await _loadRemoteImages(shell, remoteHost);
      final networks = await _loadRemoteNetworks(shell, remoteHost);
      final volumes = await _loadRemoteVolumes(shell, remoteHost);
      return EngineSnapshot(
        containers: containers,
        images: images,
        networks: networks,
        volumes: volumes,
      );
    }

    final containers = await docker.listContainers(context: contextName);
    final images = await docker.listImages(context: contextName);
    final networks = await docker.listNetworks(context: contextName);
    final volumes = await docker.listVolumes(context: contextName);
    return EngineSnapshot(
      containers: containers,
      images: images,
      networks: networks,
      volumes: volumes,
    );
  }

  Future<List<DockerContainer>> fetchContainers({
    String? contextName,
    SshHost? remoteHost,
    RemoteShellService? shell,
  }) async {
    if (remoteHost != null && shell != null) {
      return _loadRemoteContainers(shell, remoteHost);
    }
    return docker.listContainers(context: contextName);
  }

  Future<List<DockerContainer>> _loadRemoteContainers(
    RemoteShellService shell,
    SshHost host,
  ) async {
    final output = await shell.runCommand(
      host,
      "docker ps -a --format '{{json .}}'",
      timeout: const Duration(seconds: 8),
    );
    return _parseContainers(output);
  }

  Future<List<DockerImage>> _loadRemoteImages(
    RemoteShellService shell,
    SshHost host,
  ) async {
    final output = await shell.runCommand(
      host,
      "docker images --format '{{json .}}'",
      timeout: const Duration(seconds: 8),
    );
    return _parseImages(output);
  }

  Future<List<DockerNetwork>> _loadRemoteNetworks(
    RemoteShellService shell,
    SshHost host,
  ) async {
    final output = await shell.runCommand(
      host,
      "docker network ls --format '{{json .}}'",
      timeout: const Duration(seconds: 8),
    );
    return _parseNetworks(output);
  }

  Future<List<DockerVolume>> _loadRemoteVolumes(
    RemoteShellService shell,
    SshHost host,
  ) async {
    final output = await shell.runCommand(
      host,
      "docker volume ls --format '{{json .}}'",
      timeout: const Duration(seconds: 8),
    );
    final volumes = _parseVolumes(output);
    final sizes = await _loadRemoteVolumeSizes(shell, host);
    return _applyVolumeSizes(volumes, sizes);
  }

  List<DockerContainer> _parseContainers(String output) {
    final items = <DockerContainer>[];
    for (final line in const LineSplitter().convert(output)) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map<String, dynamic>) {
          final labelsRaw = (decoded['Labels'] as String?)?.trim() ?? '';
          final labels = _parseLabels(labelsRaw);
          items.add(
            DockerContainer(
              id: (decoded['ID'] as String?)?.trim() ?? '',
              name: (decoded['Names'] as String?)?.trim() ?? '',
              image: (decoded['Image'] as String?)?.trim() ?? '',
              state: (decoded['State'] as String?)?.trim() ?? '',
              status: (decoded['Status'] as String?)?.trim() ?? '',
              ports: (decoded['Ports'] as String?)?.trim() ?? '',
              command: (decoded['Command'] as String?)?.trim(),
              createdAt: (decoded['RunningFor'] as String?)?.trim(),
              composeProject: labels['com.docker.compose.project'],
              composeService: labels['com.docker.compose.service'],
              startedAt: _parseDockerDate(
                (decoded['StartedAt'] as String?)?.trim() ?? '',
              ),
            ),
          );
        }
      } catch (error, stackTrace) {
        AppLogger.w(
          'Failed to parse remote docker container entry',
          tag: 'Docker',
          error: error,
          stackTrace: stackTrace,
        );
        continue;
      }
    }
    return items;
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

  Map<String, String> _parseLabels(String labelsRaw) {
    if (labelsRaw.isEmpty) return const {};
    final entries = <String, String>{};
    for (final part in labelsRaw.split(',')) {
      final kv = part.split('=');
      if (kv.length == 2) {
        entries[kv[0].trim()] = kv[1].trim();
      }
    }
    return entries;
  }

  List<DockerImage> _parseImages(String output) {
    final items = <DockerImage>[];
    for (final line in const LineSplitter().convert(output)) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map<String, dynamic>) {
          items.add(
            DockerImage(
              id: (decoded['ID'] as String?)?.trim() ?? '',
              repository: (decoded['Repository'] as String?)?.trim() ?? '',
              tag: (decoded['Tag'] as String?)?.trim() ?? '',
              size: (decoded['Size'] as String?)?.trim() ?? '',
              createdSince: (decoded['CreatedSince'] as String?)?.trim() ?? '',
            ),
          );
        }
      } catch (error, stackTrace) {
        AppLogger.w(
          'Failed to parse remote docker image entry',
          tag: 'Docker',
          error: error,
          stackTrace: stackTrace,
        );
        continue;
      }
    }
    return items;
  }

  List<DockerNetwork> _parseNetworks(String output) {
    final items = <DockerNetwork>[];
    for (final line in const LineSplitter().convert(output)) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      try {
        final decoded = jsonDecode(trimmed);
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
          'Failed to parse remote docker network entry',
          tag: 'Docker',
          error: error,
          stackTrace: stackTrace,
        );
        continue;
      }
    }
    return items;
  }

  List<DockerVolume> _parseVolumes(String output) {
    final items = <DockerVolume>[];
    for (final line in const LineSplitter().convert(output)) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      try {
        final decoded = jsonDecode(trimmed);
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
          'Failed to parse remote docker volume entry',
          tag: 'Docker',
          error: error,
          stackTrace: stackTrace,
        );
        continue;
      }
    }
    return items;
  }

  Future<Map<String, String>> _loadRemoteVolumeSizes(
    RemoteShellService shell,
    SshHost host,
  ) async {
    try {
      final output = await shell.runCommand(
        host,
        "docker system df -v --format '{{json .}}'",
        timeout: const Duration(seconds: 8),
      );
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
            'Failed to parse remote docker volume size entry',
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
        'Failed to fetch remote docker volume sizes',
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

  String? _volumeSizeOrNull(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty || value.toUpperCase() == 'N/A') return null;
    return value;
  }
}

class EngineSnapshot {
  const EngineSnapshot({
    required this.containers,
    required this.images,
    required this.networks,
    required this.volumes,
  });

  final List<DockerContainer> containers;
  final List<DockerImage> images;
  final List<DockerNetwork> networks;
  final List<DockerVolume> volumes;
}
