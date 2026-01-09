import 'package:cwatch/app/controllers/kubernetes_context_controller.dart';
import 'package:cwatch/services/kubernetes/kubeconfig_service.dart';

class KubernetesContextBinding {
  const KubernetesContextBinding();

  KubernetesContextController create({KubeconfigService? kubeconfig}) {
    return KubernetesContextController(kubeconfig: kubeconfig);
  }
}
