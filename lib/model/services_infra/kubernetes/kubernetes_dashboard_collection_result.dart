import 'package:cwatch/model/models/kubernetes_backend.dart';
import 'package:cwatch/model/models/kubernetes/kubeconfig_context.dart';

class KubernetesDashboardCollectionResult {
  const KubernetesDashboardCollectionResult({
    required this.backend,
    required this.context,
    required this.clusterName,
    required this.namespace,
    required this.server,
    required this.nodes,
    required this.namespaces,
    required this.deployments,
    required this.pods,
    required this.services,
    required this.events,
    required this.warnings,
  });

  final KubernetesBackend backend;
  final KubeconfigContext context;
  final String clusterName;
  final String? namespace;
  final String? server;
  final Map<String, dynamic> nodes;
  final Map<String, dynamic> namespaces;
  final Map<String, dynamic> deployments;
  final Map<String, dynamic> pods;
  final Map<String, dynamic> services;
  final Map<String, dynamic> events;
  final List<String> warnings;
}
