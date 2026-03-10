import 'dart:async';

import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/services_infra/ssh/ssh_runtime_failure.dart';

import 'builtin_ssh_exceptions.dart';

class BuiltInSshFailureMapper {
  const BuiltInSshFailureMapper();

  SshRuntimeFailure map(SshHost host, Object error) {
    if (error is SshRuntimeFailure) {
      return error;
    }
    if (error is BuiltInSshAuthenticationFailed) {
      return SshRuntimeFailure(
        kind: SshRuntimeFailureKind.authenticationFailed,
        host: host,
        message: error.toString(),
      );
    }
    if (error is TimeoutException) {
      return SshRuntimeFailure(
        kind: SshRuntimeFailureKind.timedOut,
        host: host,
        message: 'SSH command timed out for ${host.name}: ${error.message ?? error}',
      );
    }
    final message = error.toString();
    if (message.contains('No SSH identity available')) {
      return SshRuntimeFailure(
        kind: SshRuntimeFailureKind.unavailable,
        host: host,
        message: 'SSH provider unavailable for ${host.name}: $message',
      );
    }
    return SshRuntimeFailure(
      kind: SshRuntimeFailureKind.commandFailed,
      host: host,
      message: 'SSH operation failed for ${host.name}: $message',
    );
  }
}
