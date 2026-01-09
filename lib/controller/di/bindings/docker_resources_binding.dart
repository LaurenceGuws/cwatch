import 'package:cwatch/controller/controllers/docker_resources_controller.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/features/docker/services/docker_client_service.dart';
import 'package:cwatch/model/services_infra/ssh/remote_shell_service.dart';

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
