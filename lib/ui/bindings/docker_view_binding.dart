import 'package:cwatch/app/controllers/docker_view_controller.dart';
import 'package:cwatch/modules/docker/services/docker_client_service.dart';

class DockerViewBinding {
  const DockerViewBinding();

  DockerViewController createController({
    required DockerClientService docker,
  }) {
    return DockerViewController(docker: docker);
  }
}
