class DockerContext {
  const DockerContext({
    required this.name,
    required this.dockerEndpoint,
    required this.current,
    this.description,
    this.kubernetesEndpoint,
    this.orchestrator,
  });

  final String name;
  final String dockerEndpoint;
  final bool current;
  final String? description;
  final String? kubernetesEndpoint;
  final String? orchestrator;
}
