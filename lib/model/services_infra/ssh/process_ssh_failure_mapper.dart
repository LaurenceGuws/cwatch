import 'dart:async';
import 'dart:io';

import 'package:cwatch/model/models/ssh_host.dart';

import 'ssh_runtime_failure.dart';

class ProcessSshFailureMapper {
  const ProcessSshFailureMapper();

  SshRuntimeFailure fromProcessResult(SshHost host, ProcessResult result) {
    final stderrOutput = (result.stderr as String?)?.trim();
    final errorMessage = stderrOutput?.isNotEmpty == true
        ? stderrOutput
        : 'SSH exited with ${result.exitCode}';

    if (stderrOutput?.contains('Permission denied') == true ||
        stderrOutput?.contains('Authentication failed') == true ||
        stderrOutput?.contains('Host key verification failed') == true ||
        result.exitCode == 255) {
      return SshRuntimeFailure(
        kind: SshRuntimeFailureKind.authenticationFailed,
        host: host,
        message: 'SSH authentication failed for ${host.name}: $errorMessage',
      );
    }

    return SshRuntimeFailure(
      kind: SshRuntimeFailureKind.commandFailed,
      host: host,
      message: errorMessage ?? 'SSH exited with ${result.exitCode}',
    );
  }

  SshRuntimeFailure map(SshHost host, Object error) {
    if (error is SshRuntimeFailure) {
      return error;
    }
    if (error is TimeoutException) {
      return SshRuntimeFailure(
        kind: SshRuntimeFailureKind.timedOut,
        host: host,
        message: 'SSH command timed out for ${host.name}: ${error.message ?? error}',
      );
    }
    if (error is ProcessException) {
      return SshRuntimeFailure(
        kind: SshRuntimeFailureKind.unavailable,
        host: host,
        message:
            'SSH provider unavailable for ${host.name}: ${error.message}',
      );
    }
    return SshRuntimeFailure(
      kind: SshRuntimeFailureKind.commandFailed,
      host: host,
      message: error.toString(),
    );
  }
}
