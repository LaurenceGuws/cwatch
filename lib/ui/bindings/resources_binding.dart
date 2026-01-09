import 'package:cwatch/app/controllers/resources_controller.dart';
import 'package:cwatch/app/services/resource_parser.dart';
import 'package:cwatch/app/services/resource_utils.dart';
import 'package:cwatch/models/ssh_host.dart';
import 'package:cwatch/services/ssh/remote_shell_service.dart';

class ResourcesBinding {
  const ResourcesBinding();

  ResourcesController create({
    required SshHost host,
    required RemoteShellService shellService,
    int historyCapacity = 30,
    double sampleWindowSeconds = 0.4,
    Duration pollInterval = const Duration(seconds: 5),
  }) {
    final parser = ResourceParser(
      host: host,
      shellService: shellService,
      sampleWindowSeconds: sampleWindowSeconds,
    );
    return ResourcesController(
      parser: parser,
      historyManager: HistoryManager(capacity: historyCapacity),
      networkRateCalculator: NetworkRateCalculator(),
      pollInterval: pollInterval,
    );
  }
}
