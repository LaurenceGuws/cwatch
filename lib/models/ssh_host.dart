class SshHost {
  const SshHost({
    required this.name,
    required this.hostname,
    required this.port,
    required this.available,
  });

  final String name;
  final String hostname;
  final int port;
  final bool available;
}
