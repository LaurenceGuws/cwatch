import 'package:flutter/widgets.dart';

import 'package:cwatch/core/models/tab_state.dart';
import 'package:cwatch/core/workspace/persistent_workspace_controller.dart';
import 'package:cwatch/core/workspace/workspace_tab.dart';
import 'package:cwatch/models/app_settings.dart';
import 'package:cwatch/models/kubernetes_workspace_state.dart';
import 'package:cwatch/services/kubernetes/kubeconfig_service.dart';
import 'package:cwatch/shared/views/shared/tabs/tab_chip.dart';

import 'kubernetes_tab_builder.dart';

class KubernetesWorkspaceController
    extends PersistentWorkspaceController<KubernetesWorkspaceState> {
  KubernetesWorkspaceController({
    required super.settingsController,
    required super.baseTabBuilder,
  });

  @override
  KubernetesWorkspaceState? readFromSettings(AppSettings settings) {
    return settings.kubernetesWorkspace;
  }

  @override
  AppSettings writeToSettings(
    AppSettings current,
    KubernetesWorkspaceState workspace,
  ) {
    return current.copyWith(kubernetesWorkspace: workspace);
  }

  @override
  KubernetesWorkspaceState createWorkspaceState(
    List<TabState> tabs,
    int selectedIndex,
  ) {
    return KubernetesWorkspaceState(tabs: tabs, selectedIndex: selectedIndex);
  }

  @override
  TabState? getTabState(Object? tabData) {
    if (tabData is KubernetesTabData) {
      return tabData.persistedState;
    }
    return null;
  }

  @override
  Future<void> restoreState() async {
    // Handled by view.
  }

  Future<void> restore({
    required KubernetesTabBuilder builder,
    required List<KubeconfigContext> contexts,
    required Widget Function(String tabId) placeholderBuilder,
    required Widget Function(KubeconfigContext context) detailsBuilder,
    required Widget Function(
      KubeconfigContext context,
      TabOptionsController options,
    )
    resourcesBuilder,
  }) async {
    final workspace = settingsController.settings.kubernetesWorkspace;
    if (workspace == null || workspace.tabs.isEmpty) return;
    if (!workspacePersistence.shouldRestore(workspace)) return;

    final restoredTabs = <WorkspaceTab>[];
    for (final state in workspace.tabs) {
      final tab = _tabFromState(
        state: state,
        contexts: contexts,
        builder: builder,
        placeholderBuilder: placeholderBuilder,
        detailsBuilder: detailsBuilder,
        resourcesBuilder: resourcesBuilder,
      );
      if (tab != null) {
        restoredTabs.add(tab);
      }
    }

    if (restoredTabs.isNotEmpty) {
      workspacePersistence.markRestored(workspace);
      replaceAll(restoredTabs, selectedIndex: workspace.selectedIndex);
    }
  }

  WorkspaceTab? _tabFromState({
    required TabState state,
    required List<KubeconfigContext> contexts,
    required KubernetesTabBuilder builder,
    required Widget Function(String tabId) placeholderBuilder,
    required Widget Function(KubeconfigContext context) detailsBuilder,
    required Widget Function(
      KubeconfigContext context,
      TabOptionsController options,
    )
    resourcesBuilder,
  }) {
    if (_isPlaceholderState(state)) {
      return builder.placeholder(
        id: state.id,
        body: placeholderBuilder(state.id),
      );
    }

    final contextName = state.contextName;
    final configPath = state.path;
    if (contextName == null || configPath == null) return null;

    final context = _findContext(contexts, contextName, configPath);
    if (context == null) return null;

    final kind = _kindFromString(state.kind);
    final customName = state.title ?? state.label;

    if (kind == KubernetesTabKind.resources) {
      final options = CompositeTabOptionsController();
      return builder.resources(
        id: state.id,
        context: context,
        customName: customName,
        optionsController: options,
        body: resourcesBuilder(context, options),
      );
    }

    return builder.details(
      id: state.id,
      context: context,
      customName: customName,
      body: detailsBuilder(context),
    );
  }

  bool _isPlaceholderState(TabState state) {
    return state.kind == 'placeholder';
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
