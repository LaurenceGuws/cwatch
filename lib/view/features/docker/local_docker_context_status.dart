import 'package:cwatch/model/models/docker_context.dart';

class LocalDockerContextStatus {
  const LocalDockerContextStatus({
    required this.context,
    required this.available,
    this.detail,
  });

  final DockerContext context;
  final bool available;
  final String? detail;
}
