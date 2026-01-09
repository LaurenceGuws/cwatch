class KubeconfigContext {
  const KubeconfigContext({
    required this.name,
    required this.cluster,
    required this.user,
    required this.namespace,
    required this.server,
    required this.configPath,
    required this.isCurrent,
  });

  final String name;
  final String? cluster;
  final String? user;
  final String? namespace;
  final String? server;
  final String configPath;
  final bool isCurrent;
}
