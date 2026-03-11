import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/model/models/docker_container.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/view/features/docker/widgets/docker_overview_container_menu_helper.dart';

void main() {
  const helper = DockerOverviewContainerMenuHelper();

  DockerContainer container(String id) => DockerContainer(
    id: id,
    name: id,
    image: 'img',
    state: 'running',
    status: 'running',
    ports: '80/tcp',
    command: 'run',
    createdAt: '1h ago',
  );

  group('DockerOverviewContainerMenuHelper', () {
    test('copyExec copies all exec commands for multi-selection', () async {
      final copied = <String>[];

      await helper.handleAction(
        action: 'copyExec',
        selection: [container('a'), container('b')],
        dockerContextNameFor: (host) => '${host.name}-docker',
        remoteHost: null,
        openLogs: (_) async {},
        openShell: (_) async {},
        copyExecCommand: (_) async {},
        execCommand: (id) => 'exec $id',
        copyExecCommands: (commands, count) async => copied.add('$count:$commands'),
        stopForwards: () async {},
        forwardPorts: (container) async {},
        openExplorer: (container, dockerContextName) async {},
        runAction: (container, action) async {},
      );

      expect(copied, ['2:exec a\nexec b']);
    });

    test('explore uses local docker context fallback when no remote host exists', () async {
      final opened = <String>[];

      await helper.handleAction(
        action: 'explore',
        selection: [container('a')],
        dockerContextNameFor: (host) => '${host.name}-docker',
        remoteHost: null,
        openLogs: (_) async {},
        openShell: (_) async {},
        copyExecCommand: (_) async {},
        execCommand: (id) => 'exec $id',
        copyExecCommands: (commands, count) async {},
        stopForwards: () async {},
        forwardPorts: (container) async {},
        openExplorer: (target, dockerContextName) async =>
            opened.add('${target.id}:$dockerContextName'),
        runAction: (container, action) async {},
      );

      expect(opened, ['a:local-docker']);
    });

    test('start runs actions for all selected containers', () async {
      final actions = <String>[];

      await helper.handleAction(
        action: 'start',
        selection: [container('a'), container('b')],
        dockerContextNameFor: (host) => '${host.name}-docker',
        remoteHost: const SshHost(
          name: 'remote',
          hostname: 'remote.example',
          port: 22,
          available: true,
        ),
        openLogs: (_) async {},
        openShell: (_) async {},
        copyExecCommand: (_) async {},
        execCommand: (id) => 'exec $id',
        copyExecCommands: (commands, count) async {},
        stopForwards: () async {},
        forwardPorts: (container) async {},
        openExplorer: (container, dockerContextName) async {},
        runAction: (target, action) async => actions.add('${target.id}:$action'),
      );

      expect(actions.toSet(), {'a:start', 'b:start'});
    });
  });
}
