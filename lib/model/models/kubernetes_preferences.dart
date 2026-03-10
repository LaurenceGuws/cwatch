import 'kubernetes_backend.dart';

class KubernetesPreferences {
  const KubernetesPreferences({
    this.configPaths = const [],
    this.backend = KubernetesBackend.cli,
  });

  final List<String> configPaths;
  final KubernetesBackend backend;

  KubernetesPreferences copyWith({
    List<String>? configPaths,
    KubernetesBackend? backend,
  }) {
    return KubernetesPreferences(
      configPaths: configPaths ?? this.configPaths,
      backend: backend ?? this.backend,
    );
  }
}
