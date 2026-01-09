import 'package:cwatch/app/controllers/docker_resources_controller.dart';
import 'package:cwatch/models/ssh_host.dart';
import 'package:cwatch/modules/docker/services/docker_client_service.dart';
import 'package:cwatch/services/ssh/remote_shell_service.dart';

class DockerResourcesBinding {
  const DockerResourcesBinding();

  DockerResourcesController create({
    required DockerClientService docker,
    String? contextName,
    SshHost? remoteHost,
    RemoteShellService? shellService,
    Duration pollInterval = const Duration(seconds: 5),
  }) {
    return DockerResourcesController(
      docker: docker,
      contextName: contextName,
      remoteHost: remoteHost,
      shellService: shellService,
      pollInterval: pollInterval,
    );
  }
}
