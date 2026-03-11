import 'package:flutter/material.dart';

import 'package:cwatch/controller/controllers/settings_controller.dart';
import 'package:cwatch/model/models/server_action.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/services_infra/cache/distro_cache_controller.dart';
import 'package:cwatch/model/services_infra/settings/app_settings_controller.dart';
import 'package:cwatch/model/services_infra/ssh/builtin/builtin_ssh_key_service.dart';
import 'package:cwatch/model/shared/services/host_shell_policy.dart';
import 'package:cwatch/model/services_infra/logging/app_logger.dart';
import 'package:cwatch/view/features/settings/settings/server_list_settings_controls.dart';
import 'package:cwatch/view/features/settings/settings/ssh_settings_controls.dart';
import 'package:cwatch/view/shared/views/shared/tabs/settings/floating_settings_window.dart';

import 'servers/host_list.dart';

class ServerHostSelectionSurface extends StatelessWidget {
  const ServerHostSelectionSurface({
    super.key,
    required this.hostsFuture,
    required this.cachedHosts,
    required this.showListSettings,
    required this.appSettingsController,
    required this.settingsController,
    required this.distroCacheController,
    required this.keyService,
    required this.lastHosts,
    required this.disabledHostKeys,
    required this.trackHostDistroChecks,
    required this.ensureDistroForHostOnDemand,
    required this.onSelect,
    required this.onActivate,
    required this.onAction,
    required this.onOpenConnectivity,
    required this.onOpenResources,
    required this.onOpenTerminal,
    required this.onOpenExplorer,
    required this.onOpenPortForward,
    required this.onHostsChanged,
    required this.onAddServer,
    required this.onToggleDisabledServersVisibility,
    required this.onCloseSettings,
  });

  final Future<List<SshHost>> hostsFuture;
  final List<SshHost> cachedHosts;
  final bool showListSettings;
  final AppSettingsController appSettingsController;
  final SettingsController settingsController;
  final DistroCacheController distroCacheController;
  final BuiltInSshKeyService keyService;
  final List<SshHost> lastHosts;
  final Set<String> disabledHostKeys;
  final void Function(
    List<SshHost> hosts, {
    required Set<String> disabledHostKeys,
  })
  trackHostDistroChecks;
  final ValueChanged<SshHost> ensureDistroForHostOnDemand;
  final ValueChanged<SshHost>? onSelect;
  final ValueChanged<SshHost> onActivate;
  final void Function(SshHost, ServerAction)? onAction;
  final ValueChanged<SshHost> onOpenConnectivity;
  final ValueChanged<SshHost> onOpenResources;
  final ValueChanged<SshHost> onOpenTerminal;
  final ValueChanged<SshHost> onOpenExplorer;
  final Future<void> Function(SshHost) onOpenPortForward;
  final VoidCallback onHostsChanged;
  final Future<void> Function(List<String> existingNames) onAddServer;
  final VoidCallback onToggleDisabledServersVisibility;
  final VoidCallback onCloseSettings;

  @override
  Widget build(BuildContext context) {
    final selection = FutureBuilder<List<SshHost>>(
      future: hostsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            cachedHosts.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError && cachedHosts.isEmpty) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final hosts = snapshot.data ?? cachedHosts;
        final shellCapableHosts = hosts
            .where((host) => !isNoShellHost(host))
            .toList();
        trackHostDistroChecks(
          shellCapableHosts,
          disabledHostKeys: disabledHostKeys,
        );
        return HostList(
          key: const ValueKey('host-list'),
          hosts: shellCapableHosts,
          onSelect: onSelect,
          onActivate: onActivate,
          settingsController: appSettingsController,
          distroCacheController: distroCacheController,
          keyService: keyService,
          onHostVisible: ensureDistroForHostOnDemand,
          onOpenConnectivity: onOpenConnectivity,
          onOpenResources: onOpenResources,
          onOpenTerminal: (host) {
            AppLogger().debug(
              'onOpenTerminal called for: ${host.name}, onAction=${onAction != null}',
              tag: 'ServersList',
            );
            onOpenTerminal(host);
          },
          onOpenExplorer: onOpenExplorer,
          onOpenPortForward: onOpenPortForward,
          onHostsChanged: onHostsChanged,
          onAddServer: onAddServer,
          showDisabledServers: false,
          onToggleDisabledServersVisibility: onToggleDisabledServersVisibility,
        );
      },
    );

    if (!showListSettings) return selection;
    return Stack(
      children: [
        selection,
        FloatingSettingsWindow(
          title: 'Server List Settings',
          onClose: onCloseSettings,
          child: Column(
            children: [
              ServerListSettingsControls(
                settings: settingsController.settings,
                settingsController: settingsController,
                hosts: lastHosts,
              ),
              const Divider(),
              SshSettingsControls(controller: settingsController),
            ],
          ),
        ),
      ],
    );
  }
}
