import 'package:cwatch/model/models/ssh_host.dart';
import '../settings/app_settings_controller.dart';
import 'builtin/builtin_ssh_key_service.dart';
import 'known_hosts_store.dart';
import 'remote_shell_service.dart';
import 'ssh_auth_coordinator.dart';
import 'ssh_shell_provider_request.dart';
import 'ssh_shell_provider_selector.dart';
import 'package:cwatch/model/models/app_settings.dart';
import '../logging/app_logger.dart';

class SshShellFactory {
  SshShellFactory({
    required this.settingsController,
    required this.keyService,
    SshAuthCoordinator? authCoordinator,
    SshShellProviderSelector? selector,
    KnownHostsStore? knownHostsStore,
    RemoteCommandObserver? observer,
  }) : knownHostsStore = knownHostsStore ?? const KnownHostsStore(),
       authCoordinator = authCoordinator ?? const SshAuthCoordinator(),
       _selector = selector ?? const SshShellProviderSelector(),
       _defaultObserver = observer ?? AppLogger.remoteCommandObserver;

  final AppSettingsController settingsController;
  final BuiltInSshKeyService keyService;
  final KnownHostsStore knownHostsStore;
  final SshAuthCoordinator authCoordinator;
  final SshShellProviderSelector _selector;
  final RemoteCommandObserver? _defaultObserver;

  RemoteShellService? _builtinShell;
  RemoteShellService? _builtinShellWithTimeout;
  RemoteShellService? _processShell;
  String? _shellSignature;
  String? _shellTimeoutSignature;

  RemoteShellService forHost(SshHost host, {Duration? connectTimeout}) {
    final settings = settingsController.settings;
    final request = _selector.select(
      settings: settings,
      connectTimeout: connectTimeout,
    );
    if (request.usesBuiltIn) {
      return _ensureBuiltinShell(settings, request);
    }
    return _ensureProcessShell(settings, request);
  }

  void handleSettingsChanged(AppSettings settings) {
    final nextSignature = _selector.settingsSignature(settings);
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

  RemoteShellService _ensureBuiltinShell(
    AppSettings settings,
    SshShellProviderRequest request,
  ) {
    if (request.connectTimeout != null) {
      final signature = request.cacheSignature;
      if (_builtinShellWithTimeout != null &&
          _shellTimeoutSignature == signature) {
        return _builtinShellWithTimeout!;
      }
      _builtinShellWithTimeout = _buildBuiltinShell(
        settings,
        connectTimeout: request.connectTimeout,
      );
      _shellTimeoutSignature = signature;
      return _builtinShellWithTimeout!;
    }
    final signature = request.cacheSignature;
    if (_builtinShell != null && _shellSignature == signature) {
      return _builtinShell!;
    }
    _builtinShell = _buildBuiltinShell(settings);
    _shellSignature = signature;
    return _builtinShell!;
  }

  RemoteShellService _ensureProcessShell(
    AppSettings settings,
    SshShellProviderRequest request,
  ) {
    final signature = request.cacheSignature;
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

  RemoteShellService _buildBuiltinShell(
    AppSettings settings, {
    Duration? connectTimeout,
  }) {
    final observer = settings.debugMode ? _defaultObserver : null;
    return keyService.buildShellService(
      hostKeyBindings: settings.sshPreferences.builtinHostKeyBindings,
      debugMode: settings.debugMode,
      observer: observer,
      knownHostsStore: knownHostsStore,
      authCoordinator: authCoordinator,
      connectTimeout: connectTimeout,
    );
  }
}
