import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/features/docker/services/docker_container_shell_service.dart';
import 'package:cwatch/model/services_infra/ssh/remote_shell_service.dart';
import 'package:cwatch/model/services_infra/ssh/ssh_shell_factory.dart';

class DockerShellCallbacks {
  const DockerShellCallbacks({required this.shellFactory});

  final SshShellFactory shellFactory;

  RemoteShellService shellForHost(SshHost host) {
    return shellFactory.forHost(host);
  }

  RemoteShellService? containerShell(
    SshHost? host,
    String? containerId, {
    String? contextName,
  }) {
    final id = containerId ?? '';
    if (host == null || host.name == 'local') {
      return LocalDockerContainerShellService(
        containerId: id,
        contextName: contextName,
      );
    }
    return DockerContainerShellService(
      host: host,
      containerId: id,
      baseShell: shellForHost(host),
    );
  }
}
