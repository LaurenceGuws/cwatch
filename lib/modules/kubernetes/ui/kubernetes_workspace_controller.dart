import 'package:cwatch/core/models/tab_state.dart';
import 'package:cwatch/core/workspace/workspace_persistence.dart';
import 'package:cwatch/models/kubernetes_workspace_state.dart';
import 'package:cwatch/services/kubernetes/kubeconfig_service.dart';
import 'package:cwatch/services/settings/app_settings_controller.dart';

import 'kubernetes_tab.dart';
import 'kubernetes_tab_factory.dart';

class KubernetesWorkspaceController {
  KubernetesWorkspaceController({
    required this.settingsController,
    required this.placeholderName,
    required this.placeholderConfig,
  }) {
    workspacePersistence = WorkspacePersistence(
      settingsController: settingsController,
      readFromSettings: (settings) => settings.kubernetesWorkspace,
      writeToSettings: (current, workspace) =>
          current.copyWith(kubernetesWorkspace: workspace),
      signatureOf: (workspace) => workspace.signature,
    );
  }

  final AppSettingsController settingsController;
  final String placeholderName;
  final String placeholderConfig;
  late final WorkspacePersistence<KubernetesWorkspaceState>
  workspacePersistence;

  KubernetesWorkspaceState currentWorkspaceState(
    List<KubernetesTab> tabs,
    int selectedIndex,
  ) {
    final states = tabs.map((tab) {
      final state = tab.workspaceState;
      if (state != null) return state;
      return tabStateFromTab(tab);
    }).toList();
    final clampedIndex = states.isEmpty
        ? 0
        : selectedIndex.clamp(0, states.length - 1);
    return KubernetesWorkspaceState(tabs: states, selectedIndex: clampedIndex);
  }

  List<KubernetesTab> buildTabsFromState({
    required KubernetesWorkspaceState workspace,
    required List<KubeconfigContext> contexts,
    required KubernetesTab? Function(TabState state) buildTab,
  }) {
    final restored = <KubernetesTab>[];
    final seen = <String>{};
    for (final state in workspace.tabs) {
      if (seen.contains(state.id)) continue;
      final tab = buildTab(state);
      if (tab == null) continue;
      if (seen.contains(tab.id)) continue;
      seen.add(tab.id);
      restored.add(tab);
    }
    return restored;
  }

  KubernetesTab? tabFromState({
    required TabState state,
    required List<KubeconfigContext> contexts,
    required KubernetesTabFactory factory,
  }) {
    if (_isPlaceholderState(state)) {
      return factory.placeholder(id: state.id);
    }
    final contextName = state.contextName;
    final configPath = state.path;
    if (contextName == null || configPath == null) return null;
    final context = _findContext(contexts, contextName, configPath);
    if (context == null) return null;
    final kind = _kindFromString(state.kind);
    return factory.contextTab(
      id: state.id,
      context: context,
      kind: kind,
      customName: state.title ?? state.label,
    );
  }

  TabState tabStateFromTab(KubernetesTab tab) {
    final ctx = tab.context;
    final isPlaceholder = ctx == null;
    return TabState(
      id: tab.id,
      kind: isPlaceholder ? 'placeholder' : tab.kind.name,
      contextName: ctx?.name ?? placeholderName,
      path: ctx?.configPath ?? placeholderConfig,
      title: tab.customName ?? tab.title,
      label: tab.customName ?? tab.label,
    );
  }

  bool _isPlaceholderState(TabState state) {
    return state.contextName == placeholderName &&
        (state.path ?? '') == placeholderConfig;
  }

  KubernetesTabKind _kindFromString(String raw) {
    return KubernetesTabKind.values.firstWhere(
      (value) => value.name == raw,
      orElse: () => KubernetesTabKind.details,
    );
  }

  KubeconfigContext? _findContext(
    List<KubeconfigContext> contexts,
    String name,
    String configPath,
  ) {
    for (final context in contexts) {
      if (context.name == name && context.configPath == configPath) {
        return context;
      }
    }
    return null;
  }
}
