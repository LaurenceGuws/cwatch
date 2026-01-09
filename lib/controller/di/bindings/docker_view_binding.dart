import 'package:cwatch/controller/controllers/docker_view_controller.dart';
import 'package:cwatch/model/features/docker/services/docker_client_service.dart';

class DockerViewBinding {
  const DockerViewBinding();

  DockerViewController createController({required DockerClientService docker}) {
    return DockerViewController(docker: docker);
  }
}
