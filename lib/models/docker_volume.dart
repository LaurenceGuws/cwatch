class DockerVolume {
  const DockerVolume({
    required this.name,
    required this.driver,
    this.mountpoint,
    this.scope,
  });

  final String name;
  final String driver;
  final String? mountpoint;
  final String? scope;
}
