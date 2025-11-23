class DockerNetwork {
  const DockerNetwork({
    required this.id,
    required this.name,
    required this.driver,
    required this.scope,
  });

  final String id;
  final String name;
  final String driver;
  final String scope;
}
