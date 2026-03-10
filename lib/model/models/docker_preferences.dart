class DockerPreferences {
  const DockerPreferences({
    this.remoteHosts = const [],
    this.selectedContext,
    this.logsTail = 200,
  });

  final List<String> remoteHosts;
  final String? selectedContext;
  final int logsTail;

  DockerPreferences copyWith({
    List<String>? remoteHosts,
    String? selectedContext,
    int? logsTail,
  }) {
    return DockerPreferences(
      remoteHosts: remoteHosts ?? this.remoteHosts,
      selectedContext: selectedContext ?? this.selectedContext,
      logsTail: logsTail ?? this.logsTail,
    );
  }
}
