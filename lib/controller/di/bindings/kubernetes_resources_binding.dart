import 'package:cwatch/controller/controllers/kubernetes_resources_controller.dart';
import 'package:cwatch/model/services_infra/kubernetes/kubectl_service.dart';

class KubernetesResourcesBinding {
  const KubernetesResourcesBinding();

  KubernetesResourcesController create({
    required String contextName,
    required String configPath,
    KubectlService? kubectl,
    Duration pollInterval = const Duration(seconds: 15),
  }) {
    return KubernetesResourcesController(
      kubectl: kubectl ?? const KubectlService(),
      contextName: contextName,
      configPath: configPath,
      pollInterval: pollInterval,
    );
  }
}
