class DockerImage {
  const DockerImage({
    required this.id,
    required this.repository,
    required this.tag,
    required this.size,
    this.createdSince,
  });

  final String id;
  final String repository;
  final String tag;
  final String size;
  final String? createdSince;
}
