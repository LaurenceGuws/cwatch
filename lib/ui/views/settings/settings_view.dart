import 'package:flutter/material.dart';

import '../../../models/ssh_host.dart';
import '../../../services/ssh/builtin/builtin_ssh_key_store.dart';
import '../../../services/ssh/builtin/builtin_ssh_vault.dart';
import '../../../services/settings/app_settings_controller.dart';
import '../../widgets/section_nav_bar.dart';
import 'settings/agents_settings_tab.dart';
import 'settings/container_settings_tabs.dart';
import 'settings/general_settings_tab.dart';
import 'settings/security_settings_tab.dart';
import 'settings/servers_settings_tab.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({
    required this.controller,
    required this.hostsFuture,
    required this.builtInKeyStore,
    required this.builtInVault,
    this.leading,
    super.key,
  });

  final AppSettingsController controller;
  final Future<List<SshHost>> hostsFuture;
  final BuiltInSshKeyStore builtInKeyStore;
  final BuiltInSshVault builtInVault;
  final Widget? leading;

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  final _agents = const [
    ('edge-01', 'Firmware 1.2.4', 'Online · 3 min ago'),
    ('edge-02', 'Firmware 1.1.9', 'Online · 2 hr ago'),
    ('workstation-lab', 'Firmware 1.0.2', 'Offline · Yesterday'),
  ];

  static const _tabs = [
    Tab(text: 'General'),
    Tab(text: 'Servers'),
    Tab(text: 'Docker'),
    Tab(text: 'Kubernetes'),
    Tab(text: 'Security'),
    Tab(text: 'Agents'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final settings = widget.controller.settings;
        return Column(
          children: [
            SectionNavBar(
              title: 'Settings',
              tabs: _tabs,
              controller: _tabController,
              showTitle: false,
              leading: widget.leading,
            ),
            Expanded(
              child: widget.controller.isLoaded
                  ? TabBarView(
                      controller: _tabController,
                      children: [
                        GeneralSettingsTab(
                          selectedTheme: settings.themeMode,
                          notificationsEnabled: settings.notificationsEnabled,
                          telemetryEnabled: settings.telemetryEnabled,
                          zoomFactor: settings.zoomFactor,
                          onThemeChanged: (mode) => widget.controller.update(
                            (current) => current.copyWith(themeMode: mode),
                          ),
                          onNotificationsChanged: (value) =>
                              widget.controller.update(
                                (current) => current.copyWith(
                                  notificationsEnabled: value,
                                ),
                              ),
                          onTelemetryChanged: (value) =>
                              widget.controller.update(
                                (current) =>
                                    current.copyWith(telemetryEnabled: value),
                              ),
                          onZoomChanged: (value) => widget.controller.update(
                            (current) => current.copyWith(zoomFactor: value),
                          ),
                        ),
                        ServersSettingsTab(
                          key: const ValueKey('servers_settings_tab'),
                          autoRefresh: settings.serverAutoRefresh,
                          showOfflineHosts: settings.serverShowOffline,
                          controller: widget.controller,
                          hostsFuture: widget.hostsFuture,
                          builtInKeyStore: widget.builtInKeyStore,
                          builtInVault: widget.builtInVault,
                          onAutoRefreshChanged: (value) =>
                              widget.controller.update(
                                (current) =>
                                    current.copyWith(serverAutoRefresh: value),
                              ),
                          onShowOfflineChanged: (value) =>
                              widget.controller.update(
                                (current) =>
                                    current.copyWith(serverShowOffline: value),
                              ),
                        ),
                        DockerSettingsTab(
                          liveStatsEnabled: settings.dockerLiveStats,
                          pruneWarningsEnabled: settings.dockerPruneWarnings,
                          onLiveStatsChanged: (value) =>
                              widget.controller.update(
                                (current) =>
                                    current.copyWith(dockerLiveStats: value),
                              ),
                          onPruneWarningsChanged: (value) =>
                              widget.controller.update(
                                (current) => current.copyWith(
                                  dockerPruneWarnings: value,
                                ),
                              ),
                        ),
                        KubernetesSettingsTab(
                          autoDiscoverEnabled: settings.kubernetesAutoDiscover,
                          includeSystemPods:
                              settings.kubernetesIncludeSystemPods,
                          onAutoDiscoverChanged: (value) =>
                              widget.controller.update(
                                (current) => current.copyWith(
                                  kubernetesAutoDiscover: value,
                                ),
                              ),
                          onIncludeSystemPodsChanged: (value) =>
                              widget.controller.update(
                                (current) => current.copyWith(
                                  kubernetesIncludeSystemPods: value,
                                ),
                              ),
                        ),
                        SecuritySettingsTab(
                          mfaRequired: settings.mfaRequired,
                          sshRotationEnabled: settings.sshRotationEnabled,
                          auditStreamingEnabled: settings.auditStreamingEnabled,
                          onMfaChanged: (value) => widget.controller.update(
                            (current) => current.copyWith(mfaRequired: value),
                          ),
                          onSshRotationChanged: (value) =>
                              widget.controller.update(
                                (current) =>
                                    current.copyWith(sshRotationEnabled: value),
                              ),
                          onAuditStreamingChanged: (value) =>
                              widget.controller.update(
                                (current) => current.copyWith(
                                  auditStreamingEnabled: value,
                                ),
                              ),
                        ),
                        AgentsSettingsTab(
                          autoUpdateAgents: settings.autoUpdateAgents,
                          agentAlertsEnabled: settings.agentAlertsEnabled,
                          agents: _agents,
                          onAutoUpdateChanged: (value) =>
                              widget.controller.update(
                                (current) =>
                                    current.copyWith(autoUpdateAgents: value),
                              ),
                          onAgentAlertsChanged: (value) =>
                              widget.controller.update(
                                (current) =>
                                    current.copyWith(agentAlertsEnabled: value),
                              ),
                        ),
                      ],
                    )
                  : const Center(child: CircularProgressIndicator()),
            ),
          ],
        );
      },
    );
  }
}
