import 'package:cwatch/app/controllers/docker_shell_callbacks.dart';
import 'package:cwatch/services/ssh/ssh_shell_factory.dart';

class DockerShellCallbacksBinding {
  const DockerShellCallbacksBinding();

  DockerShellCallbacks create({required SshShellFactory shellFactory}) {
    return DockerShellCallbacks(shellFactory: shellFactory);
  }
}
