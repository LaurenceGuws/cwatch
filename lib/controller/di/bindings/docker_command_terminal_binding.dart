import 'package:cwatch/controller/controllers/docker_command_terminal_controller.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/services_infra/ssh/remote_shell_service.dart';

class DockerCommandTerminalBinding {
  const DockerCommandTerminalBinding();

  DockerCommandTerminalController create({
    required String command,
    SshHost? host,
    RemoteShellService? shellService,
  }) {
    return DockerCommandTerminalController(
      command: command,
      host: host,
      shellService: shellService,
    );
  }
}
