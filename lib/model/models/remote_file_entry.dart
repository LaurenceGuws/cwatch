class RemoteFileEntry {
  const RemoteFileEntry({
    required this.name,
    required this.isDirectory,
    required this.sizeBytes,
    required this.modified,
  });

  final String name;
  final bool isDirectory;
  final int sizeBytes;
  final DateTime modified;
}
