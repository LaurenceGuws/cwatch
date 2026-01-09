import 'package:flutter/foundation.dart';

import 'package:cwatch/model/models/kubernetes_backend.dart';
import 'package:cwatch/model/models/kubernetes/kubeconfig_context.dart';
import 'package:cwatch/model/services_infra/kubernetes/kubernetes_dashboard_service.dart';
import 'package:cwatch/model/services_infra/logging/app_logger.dart';

class KubernetesDashboardController extends ChangeNotifier {
  KubernetesDashboardController({
    required this.service,
    required this.context,
    required KubernetesBackend initialBackend,
  }) : _backend = initialBackend;

  final KubernetesDashboardService service;
  final KubeconfigContext context;
  KubernetesBackend _backend;

  KubernetesBackend get backend => _backend;

  KubernetesDashboardSnapshot? snapshot;
  bool loading = true;
  String? error;

  String namespaceScope = _allNamespacesLabel;
  String searchQuery = '';

  static const String _allNamespacesLabel = 'All namespaces';

  Future<void> initialize() async {
    await loadSnapshot();
  }

  Future<void> loadSnapshot() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      snapshot = await service.load(backend: _backend, context: context);
      loading = false;
      error = null;
      notifyListeners();
    } catch (e, stackTrace) {
      AppLogger().warn(
        'Failed to load Kubernetes dashboard',
        tag: 'Kubernetes',
        error: e,
        stackTrace: stackTrace,
      );
      error = e.toString();
      loading = false;
      notifyListeners();
    }
  }

  void setBackend(KubernetesBackend newBackend) {
    if (newBackend == _backend) return;
    _backend = newBackend;
    loadSnapshot();
  }

  void setNamespaceScope(String value) {
    namespaceScope = value;
    notifyListeners();
  }

  void setSearchQuery(String value) {
    searchQuery = value;
    notifyListeners();
  }

  void refresh() {
    loadSnapshot();
  }
}
