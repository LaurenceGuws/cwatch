class DockerCliFailure implements Exception {
  const DockerCliFailure._({
    required this.kind,
    required this.operation,
    required this.message,
    this.contextLabel,
    this.cause,
  });

  final DockerCliFailureKind kind;
  final String operation;
  final String message;
  final String? contextLabel;
  final Object? cause;

  factory DockerCliFailure.unavailable({
    required String operation,
    required String message,
    String? contextLabel,
    Object? cause,
  }) {
    return DockerCliFailure._(
      kind: DockerCliFailureKind.unavailable,
      operation: operation,
      message: message,
      contextLabel: contextLabel,
      cause: cause,
    );
  }

  factory DockerCliFailure.timeout({
    required String operation,
    required String message,
    String? contextLabel,
    Object? cause,
  }) {
    return DockerCliFailure._(
      kind: DockerCliFailureKind.timeout,
      operation: operation,
      message: message,
      contextLabel: contextLabel,
      cause: cause,
    );
  }

  factory DockerCliFailure.processError({
    required String operation,
    required String message,
    String? contextLabel,
    Object? cause,
  }) {
    return DockerCliFailure._(
      kind: DockerCliFailureKind.processError,
      operation: operation,
      message: message,
      contextLabel: contextLabel,
      cause: cause,
    );
  }

  @override
  String toString() => message;
}

enum DockerCliFailureKind {
  unavailable,
  timeout,
  processError,
}
