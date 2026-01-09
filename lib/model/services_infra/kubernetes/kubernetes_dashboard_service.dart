import 'dart:convert';

import 'package:cwatch/model/models/kubernetes_backend.dart';
import 'package:cwatch/model/models/kubernetes/kubeconfig_context.dart';
import 'package:cwatch/model/services_infra/kubernetes/kubeconfig_service.dart';
import 'package:cwatch/model/services_infra/kubernetes/kubectl_service.dart';
import 'package:cwatch/model/services_infra/kubernetes/kubernetes_api_client.dart';

class KubernetesDashboardSnapshot {
  const KubernetesDashboardSnapshot({
    required this.backend,
    required this.collectedAt,
    required this.summary,
    required this.nodes,
    required this.namespaces,
    required this.workloads,
    required this.pods,
    required this.services,
    required this.events,
    required this.warnings,
  });

  final KubernetesBackend backend;
  final DateTime collectedAt;
  final KubernetesClusterSummary summary;
  final List<KubernetesNodeRow> nodes;
  final List<KubernetesNamespaceRow> namespaces;
  final List<KubernetesWorkloadRow> workloads;
  final List<KubernetesPodRow> pods;
  final List<KubernetesServiceRow> services;
  final List<KubernetesEventRow> events;
  final List<String> warnings;
}

class KubernetesClusterSummary {
  const KubernetesClusterSummary({
    required this.contextName,
    required this.clusterName,
    required this.namespace,
    required this.server,
    required this.nodesTotal,
    required this.nodesReady,
    required this.namespaces,
    required this.workloads,
    required this.pods,
    required this.services,
  });

  final String contextName;
  final String clusterName;
  final String? namespace;
  final String? server;
  final int nodesTotal;
  final int nodesReady;
  final int namespaces;
  final int workloads;
  final int pods;
  final int services;
}

class KubernetesNodeRow {
  const KubernetesNodeRow({
    required this.name,
    required this.ready,
    required this.roles,
    required this.kubeletVersion,
  });

  final String name;
  final bool ready;
  final String roles;
  final String kubeletVersion;
}

class KubernetesNamespaceRow {
  const KubernetesNamespaceRow({required this.name, required this.status});

  final String name;
  final String status;
}

class KubernetesWorkloadRow {
  const KubernetesWorkloadRow({
    required this.namespace,
    required this.name,
    required this.ready,
    required this.replicas,
  });

  final String namespace;
  final String name;
  final String ready;
  final String replicas;
}

class KubernetesPodRow {
  const KubernetesPodRow({
    required this.namespace,
    required this.name,
    required this.status,
    required this.node,
  });

  final String namespace;
  final String name;
  final String status;
  final String node;
}

class KubernetesServiceRow {
  const KubernetesServiceRow({
    required this.namespace,
    required this.name,
    required this.type,
    required this.clusterIp,
    required this.ports,
  });

  final String namespace;
  final String name;
  final String type;
  final String clusterIp;
  final String ports;
}

class KubernetesEventRow {
  const KubernetesEventRow({
    required this.namespace,
    required this.reason,
    required this.message,
    required this.timestamp,
  });

  final String namespace;
  final String reason;
  final String message;
  final DateTime? timestamp;
}

class KubernetesDashboardService {
  KubernetesDashboardService({
    KubectlService? kubectl,
    KubeconfigService? kubeconfig,
    KubernetesApiClient? apiClient,
  }) : _kubectl = kubectl ?? const KubectlService(),
       _kubeconfig = kubeconfig ?? const KubeconfigService(),
       _apiClient = apiClient ?? KubernetesApiClient();

  final KubectlService _kubectl;
  final KubeconfigService _kubeconfig;
  final KubernetesApiClient _apiClient;

  Future<KubernetesDashboardSnapshot> load({
    required KubernetesBackend backend,
    required KubeconfigContext context,
  }) async {
    if (backend == KubernetesBackend.api) {
      return _loadApi(context: context, backend: backend);
    }
    return _loadCli(context: context, backend: backend);
  }

  Future<KubernetesDashboardSnapshot> _loadApi({
    required KubeconfigContext context,
    required KubernetesBackend backend,
  }) async {
    final auth = await _kubeconfig.resolveAuth(
      configPath: context.configPath,
      contextName: context.name,
    );
    if (auth == null) {
      return _emptySnapshot(
        backend: backend,
        context: context,
        warnings: const ['Failed to resolve kubeconfig auth.'],
      );
    }

    final warnings = <String>[...auth.warnings];
    final nodesJson = await _safeApiJson(
      auth,
      '/api/v1/nodes',
      warnings,
      'nodes',
    );
    final namespacesJson = await _safeApiJson(
      auth,
      '/api/v1/namespaces',
      warnings,
      'namespaces',
    );
    final deploymentsJson = await _safeApiJson(
      auth,
      '/apis/apps/v1/deployments',
      warnings,
      'deployments',
      query: const {'limit': '500'},
    );
    final podsJson = await _safeApiJson(
      auth,
      '/api/v1/pods',
      warnings,
      'pods',
      query: const {'limit': '500'},
    );
    final servicesJson = await _safeApiJson(
      auth,
      '/api/v1/services',
      warnings,
      'services',
      query: const {'limit': '500'},
    );
    final eventsJson = await _safeApiJson(
      auth,
      '/api/v1/events',
      warnings,
      'events',
      query: const {'limit': '200'},
    );

    final nodes = _parseNodes(nodesJson);
    final namespaces = _parseNamespaces(namespacesJson);
    final workloads = _parseDeployments(deploymentsJson);
    final pods = _parsePods(podsJson);
    final services = _parseServices(servicesJson);
    final events = _parseEvents(eventsJson);

    final summary = KubernetesClusterSummary(
      contextName: context.name,
      clusterName: context.cluster ?? auth.clusterName,
      namespace: context.namespace ?? auth.namespace,
      server: context.server ?? auth.server,
      nodesTotal: nodes.length,
      nodesReady: nodes.where((node) => node.ready).length,
      namespaces: namespaces.length,
      workloads: workloads.length,
      pods: pods.length,
      services: services.length,
    );

    return KubernetesDashboardSnapshot(
      backend: backend,
      collectedAt: DateTime.now(),
      summary: summary,
      nodes: nodes,
      namespaces: namespaces,
      workloads: workloads,
      pods: pods,
      services: services,
      events: events,
      warnings: warnings,
    );
  }

  Future<KubernetesDashboardSnapshot> _loadCli({
    required KubeconfigContext context,
    required KubernetesBackend backend,
  }) async {
    final warnings = <String>[];
    final argsBase = [
      '--context',
      context.name,
      '--kubeconfig',
      context.configPath,
    ];

    final nodesJson = await _safeKubectlJson(
      [...argsBase, 'get', 'nodes', '-o', 'json'],
      warnings,
      'nodes',
    );
    final namespacesJson = await _safeKubectlJson(
      [...argsBase, 'get', 'namespaces', '-o', 'json'],
      warnings,
      'namespaces',
    );
    final deploymentsJson = await _safeKubectlJson(
      [...argsBase, 'get', 'deployments', '-A', '-o', 'json'],
      warnings,
      'deployments',
    );
    final podsJson = await _safeKubectlJson(
      [...argsBase, 'get', 'pods', '-A', '-o', 'json'],
      warnings,
      'pods',
    );
    final servicesJson = await _safeKubectlJson(
      [...argsBase, 'get', 'services', '-A', '-o', 'json'],
      warnings,
      'services',
    );
    final eventsJson = await _safeKubectlJson(
      [
        ...argsBase,
        'get',
        'events',
        '-A',
        '--sort-by=.metadata.creationTimestamp',
        '-o',
        'json',
      ],
      warnings,
      'events',
    );

    final nodes = _parseNodes(nodesJson);
    final namespaces = _parseNamespaces(namespacesJson);
    final workloads = _parseDeployments(deploymentsJson);
    final pods = _parsePods(podsJson);
    final services = _parseServices(servicesJson);
    final events = _parseEvents(eventsJson);

    final summary = KubernetesClusterSummary(
      contextName: context.name,
      clusterName: context.cluster ?? 'Cluster',
      namespace: context.namespace,
      server: context.server,
      nodesTotal: nodes.length,
      nodesReady: nodes.where((node) => node.ready).length,
      namespaces: namespaces.length,
      workloads: workloads.length,
      pods: pods.length,
      services: services.length,
    );

    return KubernetesDashboardSnapshot(
      backend: backend,
      collectedAt: DateTime.now(),
      summary: summary,
      nodes: nodes,
      namespaces: namespaces,
      workloads: workloads,
      pods: pods,
      services: services,
      events: events,
      warnings: warnings,
    );
  }

  Future<Map<String, dynamic>> _safeKubectlJson(
    List<String> args,
    List<String> warnings,
    String label,
  ) async {
    try {
      final output = await _kubectl.runRaw(args);
      final decoded = jsonDecode(output);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      warnings.add('Unexpected $label response format.');
    } catch (error) {
      warnings.add('Failed to load $label.');
    }
    return const {};
  }

  Future<Map<String, dynamic>> _safeApiJson(
    KubeconfigAuth auth,
    String path,
    List<String> warnings,
    String label, {
    Map<String, String>? query,
  }) async {
    try {
      return await _apiClient.getJson(
        server: auth.server,
        path: path,
        query: query,
        auth: auth,
      );
    } catch (error) {
      warnings.add('Failed to load $label.');
    }
    return const {};
  }

  List<KubernetesNodeRow> _parseNodes(Map<String, dynamic> json) {
    final items = _items(json);
    final rows = <KubernetesNodeRow>[];
    for (final item in items) {
      final metadata = _map(item['metadata']);
      final status = _map(item['status']);
      final nodeInfo = _map(status['nodeInfo']);
      final labels = _map(metadata['labels']);
      final name = _string(metadata['name']) ?? 'unknown';
      final ready = _nodeReady(status['conditions']);
      final roles = _nodeRoles(labels);
      final kubeletVersion = _string(nodeInfo['kubeletVersion']) ?? 'unknown';
      rows.add(
        KubernetesNodeRow(
          name: name,
          ready: ready,
          roles: roles,
          kubeletVersion: kubeletVersion,
        ),
      );
    }
    return rows;
  }

  List<KubernetesNamespaceRow> _parseNamespaces(Map<String, dynamic> json) {
    final items = _items(json);
    final rows = <KubernetesNamespaceRow>[];
    for (final item in items) {
      final metadata = _map(item['metadata']);
      final status = _map(item['status']);
      rows.add(
        KubernetesNamespaceRow(
          name: _string(metadata['name']) ?? 'unknown',
          status: _string(status['phase']) ?? 'unknown',
        ),
      );
    }
    return rows;
  }

  List<KubernetesWorkloadRow> _parseDeployments(Map<String, dynamic> json) {
    final items = _items(json);
    final rows = <KubernetesWorkloadRow>[];
    for (final item in items) {
      final metadata = _map(item['metadata']);
      final status = _map(item['status']);
      final ready = _int(status['readyReplicas']);
      final replicas = _int(status['replicas']);
      rows.add(
        KubernetesWorkloadRow(
          namespace: _string(metadata['namespace']) ?? 'default',
          name: _string(metadata['name']) ?? 'unknown',
          ready: ready == null || replicas == null ? '—' : '$ready/$replicas',
          replicas: replicas?.toString() ?? '—',
        ),
      );
    }
    return rows;
  }

  List<KubernetesPodRow> _parsePods(Map<String, dynamic> json) {
    final items = _items(json);
    final rows = <KubernetesPodRow>[];
    for (final item in items) {
      final metadata = _map(item['metadata']);
      final status = _map(item['status']);
      final spec = _map(item['spec']);
      rows.add(
        KubernetesPodRow(
          namespace: _string(metadata['namespace']) ?? 'default',
          name: _string(metadata['name']) ?? 'unknown',
          status: _string(status['phase']) ?? 'unknown',
          node: _string(spec['nodeName']) ?? '—',
        ),
      );
    }
    return rows;
  }

  List<KubernetesServiceRow> _parseServices(Map<String, dynamic> json) {
    final items = _items(json);
    final rows = <KubernetesServiceRow>[];
    for (final item in items) {
      final metadata = _map(item['metadata']);
      final spec = _map(item['spec']);
      final ports = _ports(spec['ports']);
      rows.add(
        KubernetesServiceRow(
          namespace: _string(metadata['namespace']) ?? 'default',
          name: _string(metadata['name']) ?? 'unknown',
          type: _string(spec['type']) ?? '—',
          clusterIp: _string(spec['clusterIP']) ?? '—',
          ports: ports,
        ),
      );
    }
    return rows;
  }

  List<KubernetesEventRow> _parseEvents(Map<String, dynamic> json) {
    final items = _items(json);
    final rows = <KubernetesEventRow>[];
    for (final item in items) {
      final metadata = _map(item['metadata']);
      final reason = _string(item['reason']) ?? '—';
      final message = _string(item['message']) ?? '—';
      final namespace = _string(metadata['namespace']) ?? '—';
      final timestamp = _parseTimestamp(
        item['eventTime'] ??
            item['lastTimestamp'] ??
            metadata['creationTimestamp'],
      );
      rows.add(
        KubernetesEventRow(
          namespace: namespace,
          reason: reason,
          message: message,
          timestamp: timestamp,
        ),
      );
    }
    rows.sort((a, b) {
      final aTime = a.timestamp?.millisecondsSinceEpoch ?? 0;
      final bTime = b.timestamp?.millisecondsSinceEpoch ?? 0;
      return bTime.compareTo(aTime);
    });
    return rows;
  }

  KubernetesDashboardSnapshot _emptySnapshot({
    required KubernetesBackend backend,
    required KubeconfigContext context,
    List<String> warnings = const [],
  }) {
    return KubernetesDashboardSnapshot(
      backend: backend,
      collectedAt: DateTime.now(),
      summary: KubernetesClusterSummary(
        contextName: context.name,
        clusterName: context.cluster ?? 'Cluster',
        namespace: context.namespace,
        server: context.server,
        nodesTotal: 0,
        nodesReady: 0,
        namespaces: 0,
        workloads: 0,
        pods: 0,
        services: 0,
      ),
      nodes: const [],
      namespaces: const [],
      workloads: const [],
      pods: const [],
      services: const [],
      events: const [],
      warnings: warnings,
    );
  }

  List<Map<String, dynamic>> _items(Map<String, dynamic> json) {
    final items = json['items'];
    if (items is List) {
      return items.whereType<Map<String, dynamic>>().toList();
    }
    return const [];
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    return const {};
  }

  String? _string(dynamic value) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return null;
  }

  int? _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }

  bool _nodeReady(dynamic conditions) {
    if (conditions is! List) return false;
    for (final entry in conditions) {
      if (entry is Map<String, dynamic>) {
        final type = _string(entry['type']);
        if (type == 'Ready') {
          return _string(entry['status']) == 'True';
        }
      }
    }
    return false;
  }

  String _nodeRoles(Map<String, dynamic> labels) {
    final roles = <String>[];
    for (final entry in labels.entries) {
      if (entry.key.startsWith('node-role.kubernetes.io/')) {
        final role = entry.key.split('/').last;
        if (role.isNotEmpty) {
          roles.add(role);
        }
      }
    }
    if (roles.isEmpty) {
      return 'worker';
    }
    roles.sort();
    return roles.join(', ');
  }

  String _ports(dynamic value) {
    if (value is! List) return '—';
    final formatted = <String>[];
    for (final entry in value) {
      if (entry is Map<String, dynamic>) {
        final port = _int(entry['port']);
        final protocol = _string(entry['protocol']);
        if (port != null) {
          formatted.add('$port${protocol != null ? '/$protocol' : ''}');
        }
      }
    }
    if (formatted.isEmpty) return '—';
    return formatted.join(', ');
  }

  DateTime? _parseTimestamp(dynamic value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}
