import 'package:cwatch/app/controllers/kubernetes_dashboard_controller.dart';
import 'package:cwatch/models/kubernetes_backend.dart';
import 'package:cwatch/models/kubernetes/kubeconfig_context.dart';
import 'package:cwatch/services/kubernetes/kubernetes_dashboard_service.dart';

class KubernetesDashboardBinding {
  const KubernetesDashboardBinding();

  KubernetesDashboardController create({
    required KubeconfigContext context,
    required KubernetesBackend initialBackend,
    KubernetesDashboardService? service,
  }) {
    return KubernetesDashboardController(
      service: service ?? KubernetesDashboardService(),
      context: context,
      initialBackend: initialBackend,
    );
  }
}
