import 'package:cwatch/controller/controllers/kubernetes_dashboard_controller.dart';
import 'package:cwatch/model/models/app_settings.dart';
import 'package:cwatch/model/models/kubernetes_backend.dart';
import 'package:cwatch/model/models/kubernetes/kubeconfig_context.dart';
import 'package:cwatch/model/services_infra/kubernetes/kubernetes_dashboard_service.dart';
import 'package:cwatch/model/services_infra/kubernetes/kubectl_service.dart';

class KubernetesDashboardBinding {
  const KubernetesDashboardBinding();

  KubernetesDashboardController create({
    required KubeconfigContext context,
    required KubernetesBackend initialBackend,
    required AppSettings settings,
    KubernetesDashboardService? service,
  }) {
    return KubernetesDashboardController(
      service:
          service ??
          KubernetesDashboardService(
            kubectl: KubectlService(
              command: settings.kubernetesPreferences.cliCommand,
            ),
          ),
      context: context,
      initialBackend: initialBackend,
    );
  }
}
