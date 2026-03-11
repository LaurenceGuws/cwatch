import 'dart:io';

import 'package:cwatch/model/models/ssh_host.dart';

import 'process_ssh_runner.dart';
import 'remote_shell_base.dart';

class ProcessSshTerminalSessionLaunchPlan {
  const ProcessSshTerminalSessionLaunchPlan({
    required this.executable,
    required this.arguments,
    required this.environment,
    required this.columns,
    required this.rows,
    required this.debugCommand,
  });

  final String executable;
  final List<String> arguments;
  final Map<String, String> environment;
  final int columns;
  final int rows;
  final String debugCommand;
}

class ProcessSshTerminalSessionPlanner {
  const ProcessSshTerminalSessionPlanner();

  ProcessSshTerminalSessionLaunchPlan createPlan({
    required SshHost host,
    required TerminalSessionOptions options,
    required ProcessSshRunner runner,
    Map<String, String>? platformEnvironment,
    bool? isWindows,
  }) {
    final windows = isWindows ?? Platform.isWindows;
    final columns = options.columns > 0 ? options.columns : 80;
    final rows = options.rows > 0 ? options.rows : 25;
    final environment = _sessionEnvironment(
      platformEnvironment: platformEnvironment,
      isWindows: windows,
    );

    if (windows) {
      final sshArgs = runner.buildSshArgumentsForTerminal(host).join(' ');
      final commandLine = 'ssh $sshArgs';
      return ProcessSshTerminalSessionLaunchPlan(
        executable: 'cmd.exe',
        arguments: ['/c', commandLine],
        environment: environment,
        columns: columns,
        rows: rows,
        debugCommand: 'cmd.exe /c "$commandLine"',
      );
    }

    final args = runner.buildSshArgumentsForTerminal(host);
    return ProcessSshTerminalSessionLaunchPlan(
      executable: 'ssh',
      arguments: args,
      environment: environment,
      columns: columns,
      rows: rows,
      debugCommand: 'ssh ${args.join(' ')}',
    );
  }

  Map<String, String> _sessionEnvironment({
    required Map<String, String>? platformEnvironment,
    required bool isWindows,
  }) {
    final env = Map<String, String>.from(platformEnvironment ?? Platform.environment);
    env.putIfAbsent('TERM', () => 'xterm-256color');
    if (isWindows) {
      env.putIfAbsent('SSH_AUTH_SOCK', () => r'\\.\pipe\openssh-ssh-agent');
    }
    return env;
  }
}
