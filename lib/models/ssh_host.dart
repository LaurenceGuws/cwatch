class SshHost {
  const SshHost({
    required this.name,
    required this.hostname,
    required this.port,
    required this.available,
    this.user,
    this.identityFiles = const [],
  });

  final String name;
  final String hostname;
  final int port;
  final bool available;
  final String? user;
  final List<String> identityFiles;
}
