import 'package:cwatch/controller/controllers/docker_shell_callbacks.dart';
import 'package:cwatch/model/services_infra/ssh/ssh_shell_factory.dart';

class DockerShellCallbacksBinding {
  const DockerShellCallbacksBinding();

  DockerShellCallbacks create({required SshShellFactory shellFactory}) {
    return DockerShellCallbacks(shellFactory: shellFactory);
  }
}
