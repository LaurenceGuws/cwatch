import 'package:cwatch/models/ssh_host.dart';

import '../../models/ssh_client_backend.dart';
import '../settings/app_settings_controller.dart';
import 'builtin/builtin_ssh_key_service.dart';
import 'known_hosts_store.dart';
import 'remote_command_logging.dart';
import 'remote_shell_service.dart';
import 'ssh_auth_coordinator.dart';

class SshShellFactory {
  SshShellFactory({
    required this.settingsController,
    required this.keyService,
    SshAuthCoordinator? authCoordinator,
    KnownHostsStore? knownHostsStore,
  })  : knownHostsStore = knownHostsStore ?? const KnownHostsStore(),
        authCoordinator = authCoordinator ?? const SshAuthCoordinator();

  final AppSettingsController settingsController;
  final BuiltInSshKeyService keyService;
  final KnownHostsStore knownHostsStore;
  final SshAuthCoordinator authCoordinator;

  RemoteShellService forHost(
    SshHost host, {
    RemoteCommandObserver? observer,
    Future<bool> Function(String keyId, String hostName, String? keyLabel)?
        promptUnlock,
    SshAuthCoordinator? coordinator,
  }) {
    final settings = settingsController.settings;
    final usingBuiltIn = settings.sshClientBackend == SshClientBackend.builtin;
    final effectiveCoordinator = coordinator ??
        (promptUnlock != null
            ? authCoordinator.withUnlockFallback(promptUnlock)
            : authCoordinator);
    if (usingBuiltIn) {
      return keyService.buildShellService(
        hostKeyBindings: settings.builtinSshHostKeyBindings,
        debugMode: settings.debugMode,
        observer: observer,
        promptUnlock: promptUnlock,
        knownHostsStore: knownHostsStore,
        authCoordinator: effectiveCoordinator,
      );
    }
    return ProcessRemoteShellService(
      debugMode: settings.debugMode,
      observer: observer,
    );
  }
}
