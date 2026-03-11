import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/services_infra/ssh/process_ssh_runner.dart';
import 'package:cwatch/model/services_infra/ssh/process_ssh_terminal_session_planner.dart';
import 'package:cwatch/model/services_infra/ssh/remote_shell_base.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const planner = ProcessSshTerminalSessionPlanner();
  const runner = ProcessSshRunner();
  const host = SshHost(
    name: 'example',
    hostname: 'example.com',
    port: 22,
    available: true,
    user: 'dev',
  );

  test('normalizes non-positive rows and columns', () {
    final plan = planner.createPlan(
      host: host,
      options: const TerminalSessionOptions(rows: 0, columns: -1),
      runner: runner,
      platformEnvironment: const {},
      isWindows: false,
    );

    expect(plan.columns, 80);
    expect(plan.rows, 25);
  });

  test('creates unix ssh launch plan with TERM default', () {
    final plan = planner.createPlan(
      host: host,
      options: const TerminalSessionOptions(rows: 30, columns: 100),
      runner: runner,
      platformEnvironment: const {'PATH': '/usr/bin'},
      isWindows: false,
    );

    expect(plan.executable, 'ssh');
    expect(plan.arguments, isNotEmpty);
    expect(plan.columns, 100);
    expect(plan.rows, 30);
    expect(plan.environment['TERM'], 'xterm-256color');
    expect(plan.environment['PATH'], '/usr/bin');
    expect(plan.debugCommand, startsWith('ssh '));
  });

  test('creates windows cmd launch plan with auth sock default', () {
    final plan = planner.createPlan(
      host: host,
      options: const TerminalSessionOptions(rows: 20, columns: 90),
      runner: runner,
      platformEnvironment: const {},
      isWindows: true,
    );

    expect(plan.executable, 'cmd.exe');
    expect(plan.arguments.first, '/c');
    expect(plan.arguments.last, startsWith('ssh '));
    expect(plan.environment['TERM'], 'xterm-256color');
    expect(plan.environment['SSH_AUTH_SOCK'], r'\\.\pipe\openssh-ssh-agent');
    expect(plan.debugCommand, contains('cmd.exe /c'));
  });

  test('preserves existing TERM and SSH_AUTH_SOCK values', () {
    final plan = planner.createPlan(
      host: host,
      options: const TerminalSessionOptions(rows: 20, columns: 90),
      runner: runner,
      platformEnvironment: const {
        'TERM': 'screen-256color',
        'SSH_AUTH_SOCK': 'custom.sock',
      },
      isWindows: true,
    );

    expect(plan.environment['TERM'], 'screen-256color');
    expect(plan.environment['SSH_AUTH_SOCK'], 'custom.sock');
  });
}
