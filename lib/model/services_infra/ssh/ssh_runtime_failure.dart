import 'package:cwatch/model/models/ssh_host.dart';

enum SshRuntimeFailureKind {
  authenticationFailed,
  unavailable,
  timedOut,
  commandFailed,
}

class SshRuntimeFailure implements Exception {
  const SshRuntimeFailure({
    required this.kind,
    required this.message,
    required this.host,
  });

  final SshRuntimeFailureKind kind;
  final String message;
  final SshHost host;

  @override
  String toString() => message;
}
