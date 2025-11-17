import 'package:flutter/material.dart';

import '../../../services/settings/app_settings_controller.dart';
import '../../widgets/section_nav_bar.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({required this.controller, this.leading, super.key});

  final AppSettingsController controller;
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
                        _GeneralSettingsTab(
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
                        _ServersSettingsTab(
                          autoRefresh: settings.serverAutoRefresh,
                          showOfflineHosts: settings.serverShowOffline,
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
                        _DockerSettingsTab(
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
                        _KubernetesSettingsTab(
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
                        _SecuritySettingsTab(
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
                        _AgentsSettingsTab(
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

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.description,
    required this.child,
  });

  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 24),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(description),
            const Divider(height: 32),
            child,
          ],
        ),
      ),
    );
  }
}

class _GeneralSettingsTab extends StatelessWidget {
  const _GeneralSettingsTab({
    required this.selectedTheme,
    required this.notificationsEnabled,
    required this.telemetryEnabled,
    required this.zoomFactor,
    required this.onThemeChanged,
    required this.onNotificationsChanged,
    required this.onTelemetryChanged,
    required this.onZoomChanged,
  });

  final ThemeMode selectedTheme;
  final bool notificationsEnabled;
  final bool telemetryEnabled;
  final double zoomFactor;
  final ValueChanged<ThemeMode> onThemeChanged;
  final ValueChanged<bool> onNotificationsChanged;
  final ValueChanged<bool> onTelemetryChanged;
  final ValueChanged<double> onZoomChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      children: [
        _SettingsSection(
          title: 'Theme',
          description: 'Switch between light, dark, or system themes.',
          child: DropdownButtonFormField<ThemeMode>(
            isExpanded: true,
            initialValue: selectedTheme,
            onChanged: (mode) {
              if (mode != null) {
                onThemeChanged(mode);
              }
            },
            items: const [
              DropdownMenuItem(
                value: ThemeMode.system,
                child: Text('System Default'),
              ),
              DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
              DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
            ],
          ),
        ),
        _SettingsSection(
          title: 'Interface Zoom',
          description: 'Scale interface text to improve readability.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Slider(
                value: zoomFactor.clamp(0.8, 1.5).toDouble(),
                min: 0.8,
                max: 1.5,
                divisions: 7,
                label: '${(zoomFactor * 100).round()}%',
                onChanged: onZoomChanged,
              ),
              Text('Current zoom: ${(zoomFactor * 100).round()}%'),
            ],
          ),
        ),
        _SettingsSection(
          title: 'Notifications',
          description: 'Manage app-level alerts for agent activity.',
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Enable notifications'),
            subtitle: const Text(
              'Receive push alerts when infrastructure changes are detected.',
            ),
            value: notificationsEnabled,
            onChanged: onNotificationsChanged,
          ),
        ),
        _SettingsSection(
          title: 'Telemetry',
          description:
              'Help improve cwatch by sharing anonymized usage metrics.',
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Share anonymous telemetry'),
            subtitle: const Text(
              'Crash reports and session performance data are uploaded securely.',
            ),
            value: telemetryEnabled,
            onChanged: onTelemetryChanged,
          ),
        ),
      ],
    );
  }
}

class _ServersSettingsTab extends StatelessWidget {
  const _ServersSettingsTab({
    required this.autoRefresh,
    required this.showOfflineHosts,
    required this.onAutoRefreshChanged,
    required this.onShowOfflineChanged,
  });

  final bool autoRefresh;
  final bool showOfflineHosts;
  final ValueChanged<bool> onAutoRefreshChanged;
  final ValueChanged<bool> onShowOfflineChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      children: [
        _SettingsSection(
          title: 'Inventory Refresh',
          description: 'Control how often server metadata is refreshed.',
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Auto-refresh server stats'),
            subtitle: const Text(
              'Periodically sync CPU, memory, and disk gauges.',
            ),
            value: autoRefresh,
            onChanged: onAutoRefreshChanged,
          ),
        ),
        _SettingsSection(
          title: 'Visibility',
          description:
              'Choose whether to show offline hosts in the servers list.',
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Show offline hosts'),
            subtitle: const Text(
              'Keep historical hosts visible for quick triage.',
            ),
            value: showOfflineHosts,
            onChanged: onShowOfflineChanged,
          ),
        ),
      ],
    );
  }
}

class _DockerSettingsTab extends StatelessWidget {
  const _DockerSettingsTab({
    required this.liveStatsEnabled,
    required this.pruneWarningsEnabled,
    required this.onLiveStatsChanged,
    required this.onPruneWarningsChanged,
  });

  final bool liveStatsEnabled;
  final bool pruneWarningsEnabled;
  final ValueChanged<bool> onLiveStatsChanged;
  final ValueChanged<bool> onPruneWarningsChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      children: [
        _SettingsSection(
          title: 'Monitoring',
          description: 'Toggle live container resource charts.',
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Enable live stats streaming'),
            subtitle: const Text(
              'Container CPU/memory metrics update every 2 seconds.',
            ),
            value: liveStatsEnabled,
            onChanged: onLiveStatsChanged,
          ),
        ),
        _SettingsSection(
          title: 'Maintenance',
          description:
              'Display safety prompts before pruning unused resources.',
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Warn before prune'),
            subtitle: const Text(
              'Surface a confirmation dialog before deleting dangling images.',
            ),
            value: pruneWarningsEnabled,
            onChanged: onPruneWarningsChanged,
          ),
        ),
      ],
    );
  }
}

class _KubernetesSettingsTab extends StatelessWidget {
  const _KubernetesSettingsTab({
    required this.autoDiscoverEnabled,
    required this.includeSystemPods,
    required this.onAutoDiscoverChanged,
    required this.onIncludeSystemPodsChanged,
  });

  final bool autoDiscoverEnabled;
  final bool includeSystemPods;
  final ValueChanged<bool> onAutoDiscoverChanged;
  final ValueChanged<bool> onIncludeSystemPodsChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      children: [
        _SettingsSection(
          title: 'Clusters',
          description: 'Automatically detect new kubeconfigs from disk.',
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Auto-discover contexts'),
            subtitle: const Text(
              'Watch ~/.kube for newly added kubeconfig files.',
            ),
            value: autoDiscoverEnabled,
            onChanged: onAutoDiscoverChanged,
          ),
        ),
        _SettingsSection(
          title: 'Namespace Filters',
          description: 'Reduce clutter by hiding platform namespaces.',
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Include system pods'),
            subtitle: const Text(
              'Show kube-system and istio-* namespaces in resource explorer.',
            ),
            value: includeSystemPods,
            onChanged: onIncludeSystemPodsChanged,
          ),
        ),
      ],
    );
  }
}

class _SecuritySettingsTab extends StatelessWidget {
  const _SecuritySettingsTab({
    required this.mfaRequired,
    required this.sshRotationEnabled,
    required this.auditStreamingEnabled,
    required this.onMfaChanged,
    required this.onSshRotationChanged,
    required this.onAuditStreamingChanged,
  });

  final bool mfaRequired;
  final bool sshRotationEnabled;
  final bool auditStreamingEnabled;
  final ValueChanged<bool> onMfaChanged;
  final ValueChanged<bool> onSshRotationChanged;
  final ValueChanged<bool> onAuditStreamingChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      children: [
        _SettingsSection(
          title: 'Access Controls',
          description: 'Protect operator access to critical resources.',
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Require MFA on sign-in'),
                subtitle: const Text(
                  'Users must register an authenticator app or security key.',
                ),
                value: mfaRequired,
                onChanged: onMfaChanged,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Enforce SSH key rotation'),
                subtitle: const Text(
                  'Keys older than 90 days automatically expire.',
                ),
                value: sshRotationEnabled,
                onChanged: onSshRotationChanged,
              ),
            ],
          ),
        ),
        _SettingsSection(
          title: 'Auditing',
          description:
              'Stream live audit events to your SIEM or download manual exports.',
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Enable audit log streaming'),
            subtitle: const Text(
              'Sends real-time events to the configured webhook endpoint.',
            ),
            value: auditStreamingEnabled,
            onChanged: onAuditStreamingChanged,
          ),
        ),
      ],
    );
  }
}

class _AgentsSettingsTab extends StatelessWidget {
  const _AgentsSettingsTab({
    required this.autoUpdateAgents,
    required this.agentAlertsEnabled,
    required this.agents,
    required this.onAutoUpdateChanged,
    required this.onAgentAlertsChanged,
  });

  final bool autoUpdateAgents;
  final bool agentAlertsEnabled;
  final List<(String, String, String)> agents;
  final ValueChanged<bool> onAutoUpdateChanged;
  final ValueChanged<bool> onAgentAlertsChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      children: [
        _SettingsSection(
          title: 'Agent Fleet',
          description: 'Keep agents healthy with automatic patches and alerts.',
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Auto-update agents'),
                subtitle: const Text(
                  'Roll out patches when new firmware is published.',
                ),
                value: autoUpdateAgents,
                onChanged: onAutoUpdateChanged,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Alert when agents go offline'),
                subtitle: const Text(
                  'Send notifications if an agent misses a heartbeat.',
                ),
                value: agentAlertsEnabled,
                onChanged: onAgentAlertsChanged,
              ),
            ],
          ),
        ),
        _SettingsSection(
          title: 'Connected Agents',
          description:
              'Review firmware versions and last heartbeat per device.',
          child: Column(
            children: agents
                .map(
                  (agent) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(agent.$1),
                    subtitle: Text(agent.$2),
                    trailing: Text(agent.$3),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}
