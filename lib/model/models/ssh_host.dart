class SshHost {
  const SshHost({
    required this.name,
    required this.hostname,
    required this.port,
    required this.available,
    this.user,
    this.identityFiles = const [],
    this.source,
  });

  final String name;
  final String hostname;
  final int port;
  final bool available;
  final String? user;
  final List<String> identityFiles;
  final String? source; // Config file path or 'custom' for manually added hosts
}
