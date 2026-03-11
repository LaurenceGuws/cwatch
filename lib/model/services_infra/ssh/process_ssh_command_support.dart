import 'package:cwatch/model/models/ssh_host.dart';

import '../logging/app_logger.dart';
import 'process_ssh_run_result_handler.dart';
import 'remote_shell_base.dart';

class ProcessSshCommandSupport {
  const ProcessSshCommandSupport({
    ProcessSshRunResultHandler? resultHandler,
  }) : _resultHandler = resultHandler ?? const ProcessSshRunResultHandler();

  final ProcessSshRunResultHandler _resultHandler;

  String emitCommandOutput({
    required RemoteShellService shell,
    required SshHost host,
    required String operation,
    required RunResult run,
    bool trimOutput = false,
  }) {
    return _resultHandler.emitOutput(
      shell: shell,
      host: host,
      operation: operation,
      run: run,
      trimOutput: trimOutput,
    );
  }

  void logCommandStart({
    required SshHost host,
    required String command,
  }) {
    AppLogger().debug(
      'Running command on ${host.name}: $command',
      tag: 'ProcessSSH',
    );
  }

  void logCommandComplete({
    required SshHost host,
    required String output,
  }) {
    AppLogger().debug(
      'Command on ${host.name} completed. Output length=${output.length}',
      tag: 'ProcessSSH',
    );
  }

  void logFailure({
    required SshHost host,
    required String operation,
    required String command,
    required Object error,
  }) {
    AppLogger.remote(tag: 'SSH', source: 'ssh', host: host).warn(
      '$operation failed',
      error: error,
      remote: RemoteCommandDetails(
        operation: operation,
        command: command,
        output: 'Error: $error',
        contextLabel: host.name,
      ),
    );
  }
}
