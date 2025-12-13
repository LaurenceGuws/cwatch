import 'package:meta/meta.dart';

import 'ssh_host.dart';

enum ExplorerContextKind { server, dockerContainer, kubernetes, unknown }

@immutable
class ExplorerContext {
  const ExplorerContext({
    required this.id,
    required this.host,
    required this.kind,
    required this.label,
  });

  final String id;
  final SshHost host;
  final ExplorerContextKind kind;
  final String label;

  factory ExplorerContext.server(SshHost host) {
    return ExplorerContext(
      id: 'server:${host.name}',
      host: host,
      kind: ExplorerContextKind.server,
      label: host.name,
    );
  }

  factory ExplorerContext.dockerContainer({
    required SshHost host,
    required String containerId,
    String? containerName,
    String? dockerContextName,
  }) {
    final normalizedId = containerId.isNotEmpty ? containerId : 'default';
    final normalizedContext = (dockerContextName?.trim().isNotEmpty ?? false)
        ? dockerContextName!.trim()
        : '${host.name}-docker';
    final label = (containerName?.trim().isNotEmpty ?? false)
        ? '${containerName!.trim()} @ $normalizedContext'
        : normalizedContext;
    return ExplorerContext(
      id: 'docker:${host.name}:$normalizedContext:$normalizedId',
      host: host,
      kind: ExplorerContextKind.dockerContainer,
      label: label,
    );
  }

  factory ExplorerContext.kubernetes({
    required SshHost host,
    required String clusterId,
    String? namespace,
    String? resourceName,
  }) {
    final clusterLabel = clusterId.isNotEmpty ? clusterId : 'cluster';
    final label = [
      if (namespace?.isNotEmpty ?? false) namespace,
      if (resourceName?.isNotEmpty ?? false) resourceName,
    ].whereType<String>().join('/');
    return ExplorerContext(
      id: 'k8s:${host.name}:$clusterLabel',
      host: host,
      kind: ExplorerContextKind.kubernetes,
      label: label.isNotEmpty ? label : 'k8s:$clusterLabel',
    );
  }
}
