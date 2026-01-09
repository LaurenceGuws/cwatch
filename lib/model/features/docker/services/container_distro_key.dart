import 'package:cwatch/model/models/docker_container.dart';

String containerDistroCacheKey(DockerContainer container) =>
    'container:${container.id}';
