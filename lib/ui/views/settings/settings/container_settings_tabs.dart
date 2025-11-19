import 'package:flutter/material.dart';

import 'settings_section.dart';

/// Docker settings tab widget
class DockerSettingsTab extends StatelessWidget {
  const DockerSettingsTab({
    super.key,
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
        SettingsSection(
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
        SettingsSection(
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

/// Kubernetes settings tab widget
class KubernetesSettingsTab extends StatelessWidget {
  const KubernetesSettingsTab({
    super.key,
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
        SettingsSection(
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
        SettingsSection(
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

