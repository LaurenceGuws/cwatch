import 'package:cwatch/model/models/app_settings.dart';
import 'package:cwatch/model/models/ssh_client_backend.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import '../logging/app_logger.dart';
import '../settings/app_settings_controller.dart';
import 'builtin/builtin_ssh_key_service.dart';
import 'known_hosts_store.dart';
import 'remote_shell_service.dart';
import 'ssh_auth_coordinator.dart';

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
    final cacheSignature = _cacheSignature(
      settings,
      connectTimeout: connectTimeout,
    );
    if (_usesBuiltIn(settings)) {
      return _ensureBuiltinShell(
        settings,
        cacheSignature: cacheSignature,
        connectTimeout: connectTimeout,
      );
    }
    return _ensureProcessShell(settings, cacheSignature: cacheSignature);
  }

  void handleSettingsChanged(AppSettings settings) {
    final nextSignature = _settingsSignature(settings);
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
    AppSettings settings, {
    required String cacheSignature,
    Duration? connectTimeout,
  }) {
    if (connectTimeout != null) {
      if (_builtinShellWithTimeout != null &&
          _shellTimeoutSignature == cacheSignature) {
        return _builtinShellWithTimeout!;
      }
      _builtinShellWithTimeout = _buildBuiltinShell(
        settings,
        connectTimeout: connectTimeout,
      );
      _shellTimeoutSignature = cacheSignature;
      return _builtinShellWithTimeout!;
    }
    if (_builtinShell != null && _shellSignature == cacheSignature) {
      return _builtinShell!;
    }
    _builtinShell = _buildBuiltinShell(settings);
    _shellSignature = cacheSignature;
    return _builtinShell!;
  }

  RemoteShellService _ensureProcessShell(
    AppSettings settings, {
    required String cacheSignature,
  }) {
    if (_processShell != null && _shellSignature == cacheSignature) {
      return _processShell!;
    }
    final observer = settings.debugMode ? _defaultObserver : null;
    _processShell = ProcessRemoteShellService(
      debugMode: settings.debugMode,
      observer: observer,
    );
    _shellSignature = cacheSignature;
    return _processShell!;
  }

  bool _usesBuiltIn(AppSettings settings) {
    return settings.sshPreferences.clientBackend == SshClientBackend.builtin;
  }

  String _settingsSignature(AppSettings settings) {
    final bindings =
        settings.sshPreferences.builtinHostKeyBindings.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key));
    final bindingsSignature = bindings
        .map((entry) => '${entry.key}:${entry.value}')
        .join(',');
    return [
      settings.sshPreferences.clientBackend.name,
      settings.debugMode,
      bindingsSignature,
    ].join('|');
  }

  String _cacheSignature(AppSettings settings, {Duration? connectTimeout}) {
    final base = _settingsSignature(settings);
    if (connectTimeout == null) {
      return base;
    }
    return '$base|timeout:${connectTimeout.inMilliseconds}';
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
