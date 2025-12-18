import 'package:cwatch/models/ssh_host.dart';
import 'package:cwatch/services/logging/app_logger.dart';
import 'package:cwatch/services/settings/app_settings_controller.dart';
import 'package:cwatch/services/ssh/ssh_shell_factory.dart';
import 'package:cwatch/modules/servers/services/host_distro_key.dart';
import 'package:cwatch/shared/services/distro_detector.dart';

/// Responsible for deriving a lightweight distro ID for a remote host and
/// persisting it so the UI can show a matching icon.
class HostDistroManager {
  HostDistroManager({
    required this.settingsController,
    required this.shellFactory,
  });

  final AppSettingsController settingsController;
  final SshShellFactory shellFactory;

  final Set<String> _inProgress = {};

  Map<String, String> get _cache => settingsController.settings.serverDistroMap;

  bool hasCached(String key) => _cache.containsKey(key);

  Future<void> ensureDistroForHost(
    SshHost host, {
    bool force = false,
    bool allowUnavailable = false,
  }) async {
    if ((!allowUnavailable && !host.available) || host.hostname.isEmpty) {
      return;
    }
    final key = hostDistroCacheKey(host);
    if (!force && _cache.containsKey(key)) {
      AppLogger.d(
        'Distro cache hit for ${host.name}: ${_cache[key]}',
        tag: 'Distro',
      );
      return;
    }
    if (_inProgress.contains(key)) {
      return;
    }

    _inProgress.add(key);
    try {
      AppLogger.d('Detecting distro for ${host.name}', tag: 'Distro');
      final shell = shellFactory.forHost(host);
      final detector = DistroDetector(
        (command, {timeout}) => shell.runCommand(
          host,
          command,
          timeout: timeout ?? const Duration(seconds: 10),
        ),
      );
      final slug = await detector.detect();
      if (slug == null) {
        AppLogger.d('Distro detection failed for ${host.name}', tag: 'Distro');
        return;
      }
      AppLogger.d('Distro for ${host.name} resolved to $slug', tag: 'Distro');
      await settingsController.update(
        (settings) => settings.copyWith(
          serverDistroMap: {...settings.serverDistroMap, key: slug},
        ),
      );
    } catch (error, stack) {
      AppLogger.w(
        'Failed to detect distro for ${host.name}',
        tag: 'Distro',
        error: error,
        stackTrace: stack,
      );
    } finally {
      _inProgress.remove(key);
    }
  }
}
