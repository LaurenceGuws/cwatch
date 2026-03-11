import 'kubernetes_backend.dart';

class KubernetesPreferences {
  const KubernetesPreferences({
    this.configPaths = const [],
    this.backend = KubernetesBackend.cli,
    this.cliCommand = 'kubectl',
  });

  final List<String> configPaths;
  final KubernetesBackend backend;
  final String cliCommand;

  KubernetesPreferences copyWith({
    List<String>? configPaths,
    KubernetesBackend? backend,
    String? cliCommand,
  }) {
    return KubernetesPreferences(
      configPaths: configPaths ?? this.configPaths,
      backend: backend ?? this.backend,
      cliCommand: cliCommand ?? this.cliCommand,
    );
  }
}
