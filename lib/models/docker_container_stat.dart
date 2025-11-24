class DockerContainerStat {
  const DockerContainerStat({
    required this.id,
    required this.name,
    required this.cpu,
    required this.memUsage,
    required this.memPercent,
    required this.netIO,
    required this.blockIO,
    required this.pids,
  });

  final String id;
  final String name;
  final String cpu;
  final String memUsage;
  final String memPercent;
  final String netIO;
  final String blockIO;
  final String pids;
}
