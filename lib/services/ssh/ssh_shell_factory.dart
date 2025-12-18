import 'package:cwatch/models/ssh_host.dart';

import '../../models/ssh_client_backend.dart';
import '../settings/app_settings_controller.dart';
import 'builtin/builtin_ssh_key_service.dart';
import 'known_hosts_store.dart';
import 'remote_command_logging.dart';
import 'remote_shell_service.dart';
import 'ssh_auth_coordinator.dart';
import '../../models/app_settings.dart';

class SshShellFactory {
  SshShellFactory({
    required this.settingsController,
    required this.keyService,
    SshAuthCoordinator? authCoordinator,
    KnownHostsStore? knownHostsStore,
    RemoteCommandObserver? observer,
  }) : knownHostsStore = knownHostsStore ?? const KnownHostsStore(),
       authCoordinator = authCoordinator ?? const SshAuthCoordinator(),
       _defaultObserver = observer;

  final AppSettingsController settingsController;
  final BuiltInSshKeyService keyService;
  final KnownHostsStore knownHostsStore;
  final SshAuthCoordinator authCoordinator;
  final RemoteCommandObserver? _defaultObserver;

  RemoteShellService? _builtinShell;
  RemoteShellService? _processShell;
  String? _shellSignature;

  RemoteShellService forHost(SshHost host) {
    final settings = settingsController.settings;
    final usingBuiltIn = settings.sshClientBackend == SshClientBackend.builtin;
    if (usingBuiltIn) {
      return _ensureBuiltinShell(settings);
    }
    return _ensureProcessShell(settings);
  }

  void handleSettingsChanged(AppSettings settings) {
    final nextSignature = _signatureFor(settings);
    if (nextSignature != _shellSignature) {
      _shellSignature = nextSignature;
      _builtinShell = null;
      _processShell = null;
    }
  }

  RemoteShellService _ensureBuiltinShell(AppSettings settings) {
    final signature = _signatureFor(settings);
    if (_builtinShell != null && _shellSignature == signature) {
      return _builtinShell!;
    }
    final observer = settings.debugMode ? _defaultObserver : null;
    _builtinShell = keyService.buildShellService(
      hostKeyBindings: settings.builtinSshHostKeyBindings,
      debugMode: settings.debugMode,
      observer: observer,
      knownHostsStore: knownHostsStore,
      authCoordinator: authCoordinator,
    );
    _shellSignature = signature;
    return _builtinShell!;
  }

  RemoteShellService _ensureProcessShell(AppSettings settings) {
    final signature = '${_signatureFor(settings)}|process';
    if (_processShell != null && _shellSignature == signature) {
      return _processShell!;
    }
    final observer = settings.debugMode ? _defaultObserver : null;
    _processShell = ProcessRemoteShellService(
      debugMode: settings.debugMode,
      observer: observer,
    );
    _shellSignature = signature;
    return _processShell!;
  }

  String _signatureFor(AppSettings settings) {
    final bindings = settings.builtinSshHostKeyBindings.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final bindingsSig = bindings
        .map((entry) => '${entry.key}:${entry.value}')
        .join(',');
    return [
      settings.sshClientBackend.name,
      settings.debugMode,
      bindingsSig,
    ].join('|');
  }
}
