import 'package:cwatch/model/models/ssh_host.dart';

import 'process_ssh_file_operation_planner.dart';
import 'process_ssh_run_result_handler.dart';
import 'remote_shell_base.dart';

class ProcessSshPathSupport {
  const ProcessSshPathSupport({
    ProcessSshFileOperationPlanner? filePlanner,
    ProcessSshRunResultHandler? resultHandler,
  }) : _filePlanner = filePlanner ?? const ProcessSshFileOperationPlanner(),
       _resultHandler = resultHandler ?? const ProcessSshRunResultHandler();

  final ProcessSshFileOperationPlanner _filePlanner;
  final ProcessSshRunResultHandler _resultHandler;

  Future<void> ensureRemoteDirectory(
    SshHost host,
    String directory, {
    required Future<RunResult> Function(SshHost host, String command) runHostCommand,
  }) async {
    if (directory.isEmpty) {
      return;
    }
    await runHostCommand(host, _filePlanner.ensureDirectoryCommand(directory));
  }

  Future<VerificationResult?> verifyPathExists(
    SshHost host,
    String path, {
    required bool shouldExist,
    required bool debugMode,
    required Future<RunResult> Function(SshHost host, String command) runSsh,
  }) async {
    if (!debugMode) {
      return null;
    }
    final command = _filePlanner.existsCheckCommand(path);
    final run = await runSsh(host, command);
    return _resultHandler.verificationFromExistsCheck(
      run: run,
      shouldExist: shouldExist,
    );
  }
}
