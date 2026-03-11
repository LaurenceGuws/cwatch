import 'package:flutter/widgets.dart';

import 'package:cwatch/controller/controllers/kubernetes_context_controller.dart';
import 'package:cwatch/model/models/kubernetes/kubeconfig_context.dart';
import 'package:cwatch/model/services_infra/settings/app_settings_controller.dart';

class KubernetesContextListState {
  Future<List<KubeconfigContext>>? contextsFuture;
  List<KubeconfigContext> cachedContexts = const [];
  final Map<String, bool> _collapsedByConfigPath = {};
  final Set<String> _selectedContextKeys = {};
  bool showListSettings = false;

  Future<List<KubeconfigContext>> loadContexts(
    KubernetesContextController contextController,
    AppSettingsController settingsController,
  ) async {
    final contexts = await contextController.loadContexts(
      contextController.resolveConfigPaths(settingsController.settings),
    );
    cachedContexts = contexts;
    return contexts;
  }

  void setContextsFuture(Future<List<KubeconfigContext>> nextContextsFuture) {
    contextsFuture = nextContextsFuture;
  }

  List<KubeconfigContext> resolveContexts(AsyncSnapshot<List<KubeconfigContext>> snapshot) {
    return snapshot.data ?? cachedContexts;
  }

  Map<String, List<KubeconfigContext>> groupByConfigPath(
    KubernetesContextController contextController,
    List<KubeconfigContext> contexts,
  ) {
    return contextController.groupByConfigPath(contexts);
  }

  bool isCollapsed(String configPath) => _collapsedByConfigPath[configPath] ?? false;

  void toggleCollapsed(String configPath) {
    _collapsedByConfigPath[configPath] = !isCollapsed(configPath);
  }

  void collapseAll() {
    for (final cfg in cachedContexts.map((c) => c.configPath).toSet()) {
      _collapsedByConfigPath[cfg] = true;
    }
  }

  void expandAll() {
    _collapsedByConfigPath.clear();
  }

  void toggleListSettings() {
    showListSettings = !showListSettings;
  }

  void updateSelectedRows(
    Iterable<KubeconfigContext> contextsForPath,
    Iterable<KubeconfigContext> selectedRows,
    String Function(KubeconfigContext) selectionKeyFor,
  ) {
    final tableKeys = contextsForPath.map(selectionKeyFor).toSet();
    _selectedContextKeys
      ..removeAll(tableKeys)
      ..addAll(selectedRows.map(selectionKeyFor));
  }
}
