enum KubernetesBackend { cli, api }

extension KubernetesBackendParsing on KubernetesBackend {
  static KubernetesBackend fromJson(String? value) {
    switch (value) {
      case 'api':
        return KubernetesBackend.api;
      case 'cli':
      default:
        return KubernetesBackend.cli;
    }
  }
}
