import 'package:cwatch/models/ssh_host.dart';

class RemoteDockerStatus {
  const RemoteDockerStatus({
    required this.host,
    required this.available,
    required this.detail,
  });

  final SshHost host;
  final bool available;
  final String detail;
}
