import 'package:cwatch/models/docker_container.dart';
import 'package:cwatch/modules/docker/services/docker_client_service.dart';
import 'package:cwatch/services/logging/app_logger.dart';
import 'package:cwatch/services/settings/app_settings_controller.dart';
import 'package:cwatch/modules/docker/services/container_distro_key.dart';
import 'package:cwatch/shared/services/distro_detector.dart';

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
    bool force = false,
  }) async {
    if (!container.isRunning) {
      return;
    }
    final key = containerDistroCacheKey(container);
    if (!force && _cache.containsKey(key)) {
      AppLogger.d(
        'Container distro cache hit for ${container.name}: ${_cache[key]}',
        tag: 'Distro',
      );
      return;
    }
    if (_inProgress.contains(key)) {
      return;
    }

    _inProgress.add(key);
    try {
      AppLogger.d(
        'Detecting distro for container ${container.name} (${container.id})',
        tag: 'Distro',
      );
      final detector = DistroDetector(
        (command, {timeout}) => docker.execInContainer(
          container.id,
          command,
          timeout: timeout ?? const Duration(seconds: 10),
        ),
      );
      final slug = await detector.detect();
      if (slug == null) {
        AppLogger.d(
          'Container distro detection failed for ${container.name}',
          tag: 'Distro',
        );
        return;
      }
      AppLogger.d(
        'Container ${container.name} resolved to $slug',
        tag: 'Distro',
      );
      await settingsController.update(
        (settings) => settings.copyWith(
          dockerDistroMap: {...settings.dockerDistroMap, key: slug},
        ),
      );
    } catch (error, stack) {
      AppLogger.w(
        'Failed to probe container distro for ${container.name}',
        tag: 'Distro',
        error: error,
        stackTrace: stack,
      );
    } finally {
      _inProgress.remove(key);
    }
  }
}
