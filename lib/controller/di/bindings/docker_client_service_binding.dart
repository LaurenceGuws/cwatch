import 'package:cwatch/model/features/docker/services/docker_client_service.dart';

class DockerClientServiceBinding {
  const DockerClientServiceBinding();

  DockerClientService create() {
    return DockerClientService();
  }
}
