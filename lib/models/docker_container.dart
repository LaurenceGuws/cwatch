class DockerContainer {
  const DockerContainer({
    required this.id,
    required this.name,
    required this.image,
    required this.state,
    required this.status,
    required this.ports,
    this.command,
    this.createdAt,
    this.composeProject,
    this.composeService,
    this.startedAt,
  });

  final String id;
  final String name;
  final String image;
  final String state;
  final String status;
  final String ports;
  final String? command;
  final String? createdAt;
  final String? composeProject;
  final String? composeService;
  final DateTime? startedAt;

  bool get isRunning => state.toLowerCase() == 'running';
}
