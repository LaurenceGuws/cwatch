import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/services_infra/cache/distro_cache_controller.dart';
import 'package:cwatch/model/services_infra/logging/app_logger.dart';
import 'package:cwatch/model/services_infra/ssh/ssh_shell_factory.dart';
import 'package:cwatch/model/features/servers/services/host_distro_key.dart';
import 'package:cwatch/model/shared/services/distro_detector.dart';
import 'package:cwatch/model/shared/services/host_shell_policy.dart';

/// Responsible for deriving a lightweight distro ID for a remote host and
/// persisting it so the UI can show a matching icon.
class HostDistroManager {
  HostDistroManager({
    required this.distroCacheController,
    required this.disabledHostKeys,
    required this.shellFactory,
  });

  final DistroCacheController distroCacheController;
  final Set<String> Function() disabledHostKeys;
  final SshShellFactory shellFactory;

  final Set<String> _inProgress = {};

  bool hasCached(String key) => distroCacheController.hasServer(key);

  bool _isHostDisabled(SshHost host) {
    final disabled = disabledHostKeys();
    return disabled.any((key) => disabledKeyMatchesHost(key, host));
  }

  Future<void> ensureDistroForHost(
    SshHost host, {
    bool force = false,
    bool allowUnavailable = false,
  }) async {
    if (isNoShellHost(host)) {
      return;
    }
    if (_isHostDisabled(host)) {
      return;
    }
    if ((!allowUnavailable && !host.available) || host.hostname.isEmpty) {
      return;
    }
    final key = hostDistroCacheKey(host);
    if (!force && distroCacheController.hasServer(key)) {
      AppLogger().debug(
        'Distro cache hit for ${host.name}: ${distroCacheController.serverSlug(key)}',
        tag: 'Distro',
      );
      return;
    }
    if (_inProgress.contains(key)) {
      return;
    }

    _inProgress.add(key);
    try {
      AppLogger().debug('Detecting distro for ${host.name}', tag: 'Distro');
      final shell = shellFactory.forHost(host);
      final remoteLogger = AppLogger.remote(
        tag: 'Distro',
        source: 'ssh',
        host: host,
      );
      final detector = DistroDetector((command, {timeout}) async {
        final effectiveTimeout = timeout ?? const Duration(seconds: 10);
        try {
          final output = await shell.runCommand(
            host,
            command,
            timeout: effectiveTimeout,
          );
          remoteLogger.trace(
            'Distro probe',
            remote: RemoteCommandDetails(
              operation: 'distro probe',
              command: command,
              output: output.trim(),
              contextLabel: host.name,
            ),
          );
          return output;
        } catch (error) {
          remoteLogger.trace(
            'Distro probe failed',
            remote: RemoteCommandDetails(
              operation: 'distro probe',
              command: command,
              output: 'Error: $error',
              contextLabel: host.name,
            ),
          );
          rethrow;
        }
      });
      final result = await detector.detectDetailed();
      final slug = result.slug;
      if (slug == null) {
        final error = result.primaryError;
        if (error == null) {
          AppLogger().debug(
            'Distro detection failed for ${host.name}',
            tag: 'Distro',
          );
        } else {
          AppLogger().debug(
            'Distro detection failed for ${host.name}: $error',
            tag: 'Distro',
          );
        }
        return;
      }
      AppLogger().debug(
        'Distro for ${host.name} resolved to $slug',
        tag: 'Distro',
      );
      await distroCacheController.putServer(key, slug);
    } catch (error, stack) {
      AppLogger().warn(
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
