import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:cwatch/model/features/servers/services/host_distro_key.dart';
import 'package:cwatch/model/features/servers/services/host_distro_manager.dart';
import 'package:cwatch/model/models/custom_ssh_host.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/services_infra/network/connectivity_probe.dart';
import 'package:cwatch/model/services_infra/settings/app_settings_controller.dart';
import 'package:cwatch/model/services_infra/ssh/ssh_config_service.dart';
import 'package:cwatch/model/shared/services/host_shell_policy.dart';

class ServerHostSurfaceController {
  ServerHostSurfaceController({
    required AppSettingsController appSettingsController,
    required HostDistroManager Function() distroManager,
    Future<List<SshHost>> Function()? loadHostsOverride,
  }) : _appSettingsController = appSettingsController,
       _distroManager = distroManager,
       _loadHostsOverride = loadHostsOverride;

  final AppSettingsController _appSettingsController;
  final HostDistroManager Function() _distroManager;
  final Future<List<SshHost>> Function()? _loadHostsOverride;

  final Map<String, bool> _hostAvailability = {};
  final Set<String> _pendingCustomAvailabilityChecks = {};
  bool _didProbeHostDistro = false;
  Future<List<SshHost>>? _loadHostsInFlight;

  final ValueNotifier<Future<List<SshHost>>> hostsFutureNotifier =
      ValueNotifier(Future.value(const []));

  Future<List<SshHost>> hostsFuture = Future.value(const []);
  List<SshHost> lastHosts = const [];

  Future<List<SshHost>> loadHosts({bool refreshAvailability = true}) async {
    final existing = _loadHostsInFlight;
    if (existing != null) {
      return existing;
    }
    final future = _loadHostsInternal(refreshAvailability: refreshAvailability);
    _loadHostsInFlight = future;
    future.whenComplete(() {
      if (identical(_loadHostsInFlight, future)) {
        _loadHostsInFlight = null;
      }
    });
    return future;
  }

  Future<List<SshHost>> _loadHostsInternal({
    required bool refreshAvailability,
  }) async {
    final override = _loadHostsOverride;
    if (override != null) {
      final hosts = await override();
      lastHosts = hosts;
      return hosts;
    }
    final settings = _appSettingsController.settings;
    final ssh = settings.sshPreferences;
    final hosts = await SshConfigService(
      customHosts: ssh.customHosts,
      additionalEntryPoints: ssh.customConfigPaths,
      disabledEntryPoints: ssh.disabledConfigPaths,
    ).loadHosts(
      disabledHosts: ssh.disabledServerHosts.toSet(),
      checkAvailability: false,
    );
    lastHosts = hosts;
    if (refreshAvailability) {
      _updateAvailabilityInBackground(hosts);
    }
    return hosts;
  }

  Future<List<SshHost>> updateCustomHosts(
    List<CustomSshHost> customHosts, {
    required VoidCallback onHostsChanged,
  }) {
    if (lastHosts.isEmpty) {
      return loadHosts();
    }
    final existingCustom = <String, SshHost>{
      for (final host in lastHosts.where((host) => host.source == 'custom'))
        _customHostKeyFromSsh(host): host,
    };
    final nonCustomHosts = lastHosts
        .where((host) => host.source != 'custom')
        .toList();
    final updatedCustomHosts = <SshHost>[];
    for (final customHost in customHosts) {
      final key = _customHostKey(customHost);
      final existing = existingCustom[key];
      final available = existing?.available ?? false;
      if (existing == null) {
        _scheduleCustomAvailabilityCheck(
          customHost,
          key,
          onHostsChanged: onHostsChanged,
        );
      }
      updatedCustomHosts.add(
        SshHost(
          name: customHost.name,
          hostname: customHost.hostname,
          port: customHost.port,
          available: available,
          user: customHost.user,
          identityFiles: customHost.identityFile != null
              ? [customHost.identityFile!]
              : const [],
          source: 'custom',
        ),
      );
    }
    final nextHosts = [...nonCustomHosts, ...updatedCustomHosts];
    lastHosts = nextHosts;
    return Future.value(nextHosts);
  }

  void setHostsFuture(Future<List<SshHost>> nextHostsFuture) {
    hostsFuture = nextHostsFuture;
    hostsFutureNotifier.value = nextHostsFuture;
  }

  void trackHostDistroChecks(
    List<SshHost> hosts, {
    required Set<String> disabledHostKeys,
  }) {
    if (_didProbeHostDistro) {
      return;
    }
    _didProbeHostDistro = true;
    for (final host in hosts) {
      if (isNoShellHost(host)) {
        continue;
      }
      if (_isHostDisabled(host, disabledHostKeys)) {
        continue;
      }
      final key = hostDistroCacheKey(host);
      _hostAvailability[key] = host.available;
    }
  }

  void ensureDistroForHostOnDemand(
    SshHost host, {
    required Set<String> disabledHostKeys,
  }) {
    if (isNoShellHost(host)) {
      return;
    }
    if (_isHostDisabled(host, disabledHostKeys)) {
      return;
    }
    final key = hostDistroCacheKey(host);
    if (_distroManager().hasCached(key)) {
      return;
    }
    if (!host.available) {
      return;
    }
    final wasAvailable = _hostAvailability[key] ?? false;
    unawaited(_distroManager().ensureDistroForHost(host, force: !wasAvailable));
  }

  void resetAvailabilityTracking() {
    _hostAvailability.clear();
    _didProbeHostDistro = false;
  }

  String buildCustomHostsSignature() {
    final settings = _appSettingsController.settings;
    final customHosts = settings.sshPreferences.customHosts.map((host) {
      final keyParts = [
        host.name,
        host.hostname,
        host.port.toString(),
        host.user ?? '',
        host.identityFile ?? '',
      ];
      return {'key': keyParts.join('|'), 'host': host.toJson()};
    }).toList()
      ..sort((a, b) => (a['key'] as String).compareTo(b['key'] as String));
    return jsonEncode(customHosts.map((entry) => entry['host']).toList());
  }

  String buildPathsSignature() {
    final settings = _appSettingsController.settings;
    final customPaths = [...settings.sshPreferences.customConfigPaths]..sort();
    final disabledPaths = [...settings.sshPreferences.disabledConfigPaths]
      ..sort();
    return jsonEncode({
      'customPaths': customPaths,
      'disabledPaths': disabledPaths,
    });
  }

  void dispose() {
    hostsFutureNotifier.dispose();
  }

  void _updateAvailabilityInBackground(List<SshHost> hosts) {
    for (final host in hosts) {
      if (isNoShellHost(host) ||
          _isHostDisabled(host, _disabledHostKeys())) {
        continue;
      }
      unawaited(
        _checkAvailabilityForHost(host).then((available) {
          final index = lastHosts.indexWhere(
            (h) =>
                h.name == host.name &&
                h.hostname == host.hostname &&
                h.port == host.port,
          );
          if (index != -1 && lastHosts[index].available != available) {
            final existing = lastHosts[index];
            final updated = SshHost(
              name: existing.name,
              hostname: existing.hostname,
              port: existing.port,
              available: available,
              user: existing.user,
              identityFiles: existing.identityFiles,
              source: existing.source,
            );
            final nextHosts = [...lastHosts];
            nextHosts[index] = updated;
            lastHosts = nextHosts;
            setHostsFuture(Future.value(nextHosts));
          }
        }),
      );
    }
  }

  Future<bool> _checkAvailabilityForHost(SshHost host) async {
    const probe = ConnectivityProbe();
    return probe.canConnect(
      host: host.hostname,
      port: host.port,
      timeout: const Duration(seconds: 2),
      hostLabel: host.name,
    );
  }

  void _scheduleCustomAvailabilityCheck(
    CustomSshHost host,
    String key, {
    required VoidCallback onHostsChanged,
  }) {
    if (!_pendingCustomAvailabilityChecks.add(key)) {
      return;
    }
    unawaited(
      _checkAvailability(host)
          .then((available) {
            _applyCustomAvailability(host, available);
            onHostsChanged();
          })
          .whenComplete(() {
            _pendingCustomAvailabilityChecks.remove(key);
          }),
    );
  }

  void _applyCustomAvailability(CustomSshHost host, bool available) {
    final key = _customHostKey(host);
    final index = lastHosts.indexWhere(
      (entry) => entry.source == 'custom' && _customHostKeyFromSsh(entry) == key,
    );
    if (index == -1) {
      return;
    }
    final existing = lastHosts[index];
    if (existing.available == available) {
      return;
    }
    final updated = SshHost(
      name: existing.name,
      hostname: existing.hostname,
      port: existing.port,
      available: available,
      user: existing.user,
      identityFiles: existing.identityFiles,
      source: existing.source,
    );
    final nextHosts = [...lastHosts];
    nextHosts[index] = updated;
    lastHosts = nextHosts;
    setHostsFuture(Future.value(nextHosts));

    final distroKey = hostDistroCacheKey(updated);
    final wasAvailable = _hostAvailability[distroKey] ?? false;
    _hostAvailability[distroKey] = available;
    if (available && !_distroManager().hasCached(distroKey)) {
      unawaited(
        _distroManager().ensureDistroForHost(updated, force: !wasAvailable),
      );
    }
  }

  Future<bool> _checkAvailability(CustomSshHost host) {
    const probe = ConnectivityProbe();
    return probe.canConnect(
      host: host.hostname,
      port: host.port,
      timeout: const Duration(seconds: 2),
      hostLabel: host.name,
    );
  }

  String _customHostKey(CustomSshHost host) {
    return [
      host.name,
      host.hostname,
      host.port.toString(),
      host.user ?? '',
      host.identityFile ?? '',
    ].join('|');
  }

  String _customHostKeyFromSsh(SshHost host) {
    return [
      host.name,
      host.hostname,
      host.port.toString(),
      host.user ?? '',
      host.identityFiles.isNotEmpty ? host.identityFiles.first : '',
    ].join('|');
  }

  Set<String> _disabledHostKeys() =>
      _appSettingsController.settings.sshPreferences.disabledServerHosts.toSet();

  bool _isHostDisabled(SshHost host, Set<String> disabledHostKeys) =>
      disabledHostKeys.any((key) => disabledKeyMatchesHost(key, host));
}
