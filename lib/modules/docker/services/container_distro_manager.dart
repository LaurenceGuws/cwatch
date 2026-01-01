import 'package:cwatch/models/docker_container.dart';
import 'package:cwatch/models/ssh_host.dart';
import 'package:cwatch/modules/docker/services/docker_client_service.dart';
import 'package:cwatch/services/logging/app_logger.dart';
import 'package:cwatch/services/settings/app_settings_controller.dart';
import 'package:cwatch/modules/docker/services/container_distro_key.dart';
import 'package:cwatch/shared/services/distro_detector.dart';
import 'package:cwatch/services/ssh/remote_shell_service.dart';

/// Tracks distro metadata for Docker containers so entries can display
/// distro-aware icons.
class ContainerDistroManager {
  ContainerDistroManager({
    required this.settingsController,
    required this.docker,
  });

  final AppSettingsController settingsController;
  final DockerClientService docker;

  final Set<String> _inProgress = {};

  Map<String, String> get _cache => settingsController.settings.dockerDistroMap;

  bool hasCached(String key) => _cache.containsKey(key);

  Future<void> ensureDistroForContainer(
    DockerContainer container, {
    String? contextName,
    SshHost? remoteHost,
    RemoteShellService? shellService,
    bool force = false,
  }) async {
    if (!container.isRunning) {
      return;
    }
    final key = containerDistroCacheKey(container);
    if (!force && _cache.containsKey(key)) {
      AppLogger().debug(
        'Container distro cache hit for ${container.name}: ${_cache[key]}',
        tag: 'Distro',
      );
      return;
    }
    if (_inProgress.contains(key)) {
      return;
    }

    _inProgress.add(key);
    final contextLabel = _contextLabel(
      contextName: contextName,
      remoteHost: remoteHost,
    );
    final remoteLogger = AppLogger.remote(
      tag: 'Docker',
      source: 'docker',
      host: remoteHost,
    );
    try {
      AppLogger().debug(
        'Detecting distro for container ${container.name} (${container.id})',
        tag: 'Distro',
      );
      final detector = DistroDetector(
        (command, {timeout}) async {
          final effectiveTimeout = timeout ?? const Duration(seconds: 10);
          if (remoteHost != null && shellService != null) {
            final escaped = _escapeSingleQuotes(command);
            final dockerCommand =
                "docker exec -i ${container.id} sh -c '$escaped'";
            return _runRemoteDockerExec(
              remoteLogger: remoteLogger,
              command: dockerCommand,
              contextLabel: contextLabel,
              timeout: effectiveTimeout,
              runner: () => shellService.runCommand(
                remoteHost,
                dockerCommand,
                timeout: effectiveTimeout,
              ),
            );
          }
          final escaped = _escapeSingleQuotes(command);
          final dockerCommand =
              "docker exec -i ${container.id} sh -c '$escaped'";
          try {
            final output = await docker.execInContainer(
              container.id,
              command,
              context: contextName,
              timeout: effectiveTimeout,
            );
            remoteLogger.trace(
              'Distro probe',
              remote: RemoteCommandDetails(
                operation: 'exec',
                command: dockerCommand,
                output: output,
                contextLabel: contextLabel,
              ),
            );
            return output;
          } catch (error) {
            remoteLogger.trace(
              'Distro probe failed',
              remote: RemoteCommandDetails(
                operation: 'exec',
                command: dockerCommand,
                output: 'Error: $error',
                contextLabel: contextLabel,
              ),
            );
            rethrow;
          }
        },
      );
      final slug = await detector.detect();
      if (slug == null) {
        AppLogger().debug(
          'Container distro detection failed for ${container.name}',
          tag: 'Distro',
        );
        return;
      }
      AppLogger().debug(
        'Container ${container.name} resolved to $slug',
        tag: 'Distro',
      );
      await settingsController.update(
        (settings) => settings.copyWith(
          dockerDistroMap: {...settings.dockerDistroMap, key: slug},
        ),
      );
    } catch (error, stack) {
      AppLogger().warn(
        'Failed to probe container distro for ${container.name}',
        tag: 'Distro',
        error: error,
        stackTrace: stack,
      );
    } finally {
      _inProgress.remove(key);
    }
  }

  String _escapeSingleQuotes(String value) {
    return value.replaceAll("'", "'\"'\"'");
  }

  String _contextLabel({String? contextName, SshHost? remoteHost}) {
    if (remoteHost != null && remoteHost.name.trim().isNotEmpty) {
      return remoteHost.name.trim();
    }
    final trimmed = contextName?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      return trimmed;
    }
    return 'default';
  }

  Future<String> _runRemoteDockerExec({
    required AppLogger remoteLogger,
    required String command,
    required String contextLabel,
    required Duration timeout,
    required Future<String> Function() runner,
  }) async {
    try {
      final output = await runner();
      remoteLogger.trace(
        'Distro probe',
        remote: RemoteCommandDetails(
          operation: 'exec',
          command: command,
          output: output,
          contextLabel: contextLabel,
        ),
      );
      return output;
    } catch (error) {
      remoteLogger.trace(
        'Distro probe failed',
        remote: RemoteCommandDetails(
          operation: 'exec',
          command: command,
          output: 'Error: $error',
          contextLabel: contextLabel,
        ),
      );
      rethrow;
    }
  }
}
