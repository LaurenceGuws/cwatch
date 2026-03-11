import 'package:cwatch/model/models/ssh_host.dart';

import 'remote_shell_base.dart';

class ProcessSshRunResultHandler {
  const ProcessSshRunResultHandler();

  String emitOutput({
    required RemoteShellService shell,
    required SshHost host,
    required String operation,
    required RunResult run,
    VerificationResult? verification,
    bool trimOutput = false,
  }) {
    final output = trimOutput ? run.stdout.trim() : run.stdout;
    shell.emitDebugEvent(
      host: host,
      operation: operation,
      command: run.command,
      output: output,
      verification: verification,
    );
    return output;
  }

  VerificationResult verificationFromExistsCheck({
    required RunResult run,
    required bool shouldExist,
  }) {
    final exists = run.stdout.trim() == 'EXISTS';
    return VerificationResult(
      command: run.command,
      output: run.stdout,
      passed: shouldExist ? exists : !exists,
    );
  }
}
