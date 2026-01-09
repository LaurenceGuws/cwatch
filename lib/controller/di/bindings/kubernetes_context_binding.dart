import 'package:cwatch/controller/controllers/kubernetes_context_controller.dart';
import 'package:cwatch/model/services_infra/kubernetes/kubeconfig_service.dart';

class KubernetesContextBinding {
  const KubernetesContextBinding();

  KubernetesContextController create({KubeconfigService? kubeconfig}) {
    return KubernetesContextController(kubeconfig: kubeconfig);
  }
}
