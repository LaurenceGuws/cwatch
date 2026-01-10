import 'package:cwatch/model/models/ssh_host.dart';

import 'package:cwatch/model/models/ssh_client_backend.dart';
import '../settings/app_settings_controller.dart';
import 'builtin/builtin_ssh_key_service.dart';
import 'known_hosts_store.dart';
import 'remote_shell_service.dart';
import 'ssh_auth_coordinator.dart';
import 'package:cwatch/model/models/app_settings.dart';
import '../logging/app_logger.dart';

class SshShellFactory {
  SshShellFactory({
    required this.settingsController,
    required this.keyService,
    SshAuthCoordinator? authCoordinator,
    KnownHostsStore? knownHostsStore,
    RemoteCommandObserver? observer,
  }) : knownHostsStore = knownHostsStore ?? const KnownHostsStore(),
       authCoordinator = authCoordinator ?? const SshAuthCoordinator(),
       _defaultObserver = observer ?? AppLogger.remoteCommandObserver;

  final AppSettingsController settingsController;
  final BuiltInSshKeyService keyService;
  final KnownHostsStore knownHostsStore;
  final SshAuthCoordinator authCoordinator;
  final RemoteCommandObserver? _defaultObserver;

  RemoteShellService? _builtinShell;
  RemoteShellService? _builtinShellWithTimeout;
  RemoteShellService? _processShell;
  String? _shellSignature;
  String? _shellTimeoutSignature;

  RemoteShellService forHost(SshHost host, {Duration? connectTimeout}) {
    final settings = settingsController.settings;
    final usingBuiltIn = settings.sshClientBackend == SshClientBackend.builtin;
    if (usingBuiltIn) {
      if (connectTimeout != null) {
        return _ensureBuiltinShellWithTimeout(settings, connectTimeout);
      }
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
    if (_shellTimeoutSignature != null &&
        !_shellTimeoutSignature!.startsWith(nextSignature)) {
      _shellTimeoutSignature = null;
      _builtinShellWithTimeout = null;
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

  RemoteShellService _ensureBuiltinShellWithTimeout(
    AppSettings settings,
    Duration connectTimeout,
  ) {
    final signature =
        '${_signatureFor(settings)}|timeout:${connectTimeout.inMilliseconds}';
    if (_builtinShellWithTimeout != null &&
        _shellTimeoutSignature == signature) {
      return _builtinShellWithTimeout!;
    }
    final observer = settings.debugMode ? _defaultObserver : null;
    _builtinShellWithTimeout = keyService.buildShellService(
      hostKeyBindings: settings.builtinSshHostKeyBindings,
      debugMode: settings.debugMode,
      observer: observer,
      knownHostsStore: knownHostsStore,
      authCoordinator: authCoordinator,
      connectTimeout: connectTimeout,
    );
    _shellTimeoutSignature = signature;
    return _builtinShellWithTimeout!;
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
