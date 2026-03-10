import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/model/models/kubernetes_backend.dart';
import 'package:cwatch/model/models/kubernetes/kubeconfig_context.dart';
import 'package:cwatch/model/services_infra/kubernetes/kubeconfig_service.dart';
import 'package:cwatch/model/services_infra/kubernetes/kubectl_service.dart';
import 'package:cwatch/model/services_infra/kubernetes/kubernetes_api_client.dart';
import 'package:cwatch/model/services_infra/kubernetes/kubernetes_dashboard_service.dart';

void main() {
  group('KubernetesDashboardService', () {
    test('CLI backend shapes dashboard data from kubectl json', () async {
      final service = KubernetesDashboardService(
        kubectl: _FakeKubectlService(
          outputs: {
            'get nodes': jsonEncode({
              'items': [
                {
                  'metadata': {
                    'name': 'node-a',
                    'labels': {'node-role.kubernetes.io/control-plane': ''},
                  },
                  'status': {
                    'conditions': [
                      {'type': 'Ready', 'status': 'True'},
                    ],
                    'nodeInfo': {'kubeletVersion': 'v1.30.0'},
                  },
                },
              ],
            }),
            'get namespaces': jsonEncode({
              'items': [
                {
                  'metadata': {'name': 'default'},
                  'status': {'phase': 'Active'},
                },
              ],
            }),
            'get deployments': jsonEncode({
              'items': [
                {
                  'metadata': {'namespace': 'default', 'name': 'web'},
                  'status': {'readyReplicas': 1, 'replicas': 2},
                },
              ],
            }),
            'get pods': jsonEncode({
              'items': [
                {
                  'metadata': {'namespace': 'default', 'name': 'web-123'},
                  'status': {'phase': 'Running'},
                  'spec': {'nodeName': 'node-a'},
                },
              ],
            }),
            'get services': jsonEncode({
              'items': [
                {
                  'metadata': {'namespace': 'default', 'name': 'web'},
                  'spec': {
                    'type': 'ClusterIP',
                    'clusterIP': '10.0.0.1',
                    'ports': [
                      {'port': 80, 'protocol': 'TCP'},
                    ],
                  },
                },
              ],
            }),
            'get events': jsonEncode({
              'items': [
                {
                  'metadata': {
                    'namespace': 'default',
                    'creationTimestamp': '2026-03-10T10:11:12Z',
                  },
                  'reason': 'Started',
                  'message': 'Started container web',
                },
              ],
            }),
          },
        ),
      );

      final snapshot = await service.load(
        backend: KubernetesBackend.cli,
        context: _context(),
      );

      expect(snapshot.backend, KubernetesBackend.cli);
      expect(snapshot.summary.contextName, 'prod');
      expect(snapshot.summary.clusterName, 'cluster-a');
      expect(snapshot.summary.nodesTotal, 1);
      expect(snapshot.summary.nodesReady, 1);
      expect(snapshot.summary.namespaces, 1);
      expect(snapshot.summary.workloads, 1);
      expect(snapshot.summary.pods, 1);
      expect(snapshot.summary.services, 1);
      expect(snapshot.nodes.single.name, 'node-a');
      expect(snapshot.nodes.single.ready, isTrue);
      expect(snapshot.nodes.single.roles, contains('control-plane'));
      expect(snapshot.workloads.single.ready, '1/2');
      expect(snapshot.pods.single.node, 'node-a');
      expect(snapshot.services.single.ports, '80/TCP');
      expect(snapshot.events.single.reason, 'Started');
      expect(snapshot.warnings, isEmpty);
    });

    test('CLI backend degrades to warnings and empty sections when kubectl fails', () async {
      final service = KubernetesDashboardService(
        kubectl: _FakeKubectlService(
          errors: {
            'get nodes': Exception('kubectl missing'),
            'get namespaces': Exception('kubectl missing'),
            'get deployments': Exception('kubectl missing'),
            'get pods': Exception('kubectl missing'),
            'get services': Exception('kubectl missing'),
            'get events': Exception('kubectl missing'),
          },
        ),
      );

      final snapshot = await service.load(
        backend: KubernetesBackend.cli,
        context: _context(),
      );

      expect(snapshot.backend, KubernetesBackend.cli);
      expect(snapshot.nodes, isEmpty);
      expect(snapshot.namespaces, isEmpty);
      expect(snapshot.workloads, isEmpty);
      expect(snapshot.pods, isEmpty);
      expect(snapshot.services, isEmpty);
      expect(snapshot.events, isEmpty);
      expect(snapshot.warnings, containsAll([
        'Failed to load nodes.',
        'Failed to load namespaces.',
        'Failed to load deployments.',
        'Failed to load pods.',
        'Failed to load services.',
        'Failed to load events.',
      ]));
    });

    test('API backend returns empty snapshot with warning when kubeconfig auth cannot be resolved', () async {
      final service = KubernetesDashboardService(
        kubeconfig: const _FakeKubeconfigService(resolveAuthResult: null),
      );

      final snapshot = await service.load(
        backend: KubernetesBackend.api,
        context: _context(),
      );

      expect(snapshot.backend, KubernetesBackend.api);
      expect(snapshot.summary.contextName, 'prod');
      expect(snapshot.summary.clusterName, 'cluster-a');
      expect(snapshot.nodes, isEmpty);
      expect(snapshot.namespaces, isEmpty);
      expect(snapshot.workloads, isEmpty);
      expect(snapshot.pods, isEmpty);
      expect(snapshot.services, isEmpty);
      expect(snapshot.events, isEmpty);
      expect(snapshot.warnings, ['Failed to resolve kubeconfig auth.']);
    });

    test('API backend degrades failed calls into warnings while keeping successful data', () async {
      final service = KubernetesDashboardService(
        kubeconfig: _FakeKubeconfigService(
          resolveAuthResult: KubeconfigAuth(
            server: 'https://cluster-a',
            contextName: 'prod',
            clusterName: 'cluster-a',
            userName: 'alice',
            namespace: 'default',
            insecureSkipTlsVerify: false,
            warnings: const ['token from exec unsupported'],
          ),
        ),
        apiClient: _FakeKubernetesApiClient(
          responses: {
            '/api/v1/nodes': {
              'items': [
                {
                  'metadata': {'name': 'node-a', 'labels': const {}},
                  'status': {
                    'conditions': [
                      {'type': 'Ready', 'status': 'True'},
                    ],
                    'nodeInfo': {'kubeletVersion': 'v1.30.0'},
                  },
                },
              ],
            },
            '/api/v1/namespaces': {
              'items': [
                {
                  'metadata': {'name': 'default'},
                  'status': {'phase': 'Active'},
                },
              ],
            },
            '/api/v1/services': {
              'items': [
                {
                  'metadata': {'namespace': 'default', 'name': 'api'},
                  'spec': {
                    'type': 'ClusterIP',
                    'clusterIP': '10.0.0.2',
                    'ports': [
                      {'port': 443, 'protocol': 'TCP'},
                    ],
                  },
                },
              ],
            },
          },
          errors: {
            '/apis/apps/v1/deployments': Exception('deployments unavailable'),
            '/api/v1/pods': Exception('pods unavailable'),
            '/api/v1/events': Exception('events unavailable'),
          },
        ),
      );

      final snapshot = await service.load(
        backend: KubernetesBackend.api,
        context: _context(),
      );

      expect(snapshot.backend, KubernetesBackend.api);
      expect(snapshot.summary.clusterName, 'cluster-a');
      expect(snapshot.summary.namespace, 'default');
      expect(snapshot.nodes.single.name, 'node-a');
      expect(snapshot.namespaces.single.name, 'default');
      expect(snapshot.services.single.name, 'api');
      expect(snapshot.workloads, isEmpty);
      expect(snapshot.pods, isEmpty);
      expect(snapshot.events, isEmpty);
      expect(snapshot.warnings, contains('token from exec unsupported'));
      expect(snapshot.warnings, contains('Failed to load deployments.'));
      expect(snapshot.warnings, contains('Failed to load pods.'));
      expect(snapshot.warnings, contains('Failed to load events.'));
    });
  });
}

KubeconfigContext _context() {
  return const KubeconfigContext(
    name: 'prod',
    cluster: 'cluster-a',
    user: 'alice',
    namespace: 'default',
    server: 'https://cluster-a',
    configPath: '/tmp/kubeconfig',
    isCurrent: true,
  );
}

class _FakeKubectlService extends KubectlService {
  _FakeKubectlService({
    this.outputs = const {},
    this.errors = const {},
  });

  final Map<String, String> outputs;
  final Map<String, Object> errors;

  @override
  Future<String> runRaw(List<String> args) async {
    final command = _matchKey(args);
    final error = errors[command];
    if (error != null) {
      throw error;
    }
    return outputs[command] ?? jsonEncode({'items': []});
  }

  String _matchKey(List<String> args) {
    final getIndex = args.indexOf('get');
    if (getIndex == -1 || getIndex + 1 >= args.length) {
      return args.join(' ');
    }
    return 'get ${args[getIndex + 1]}';
  }
}

class _FakeKubeconfigService extends KubeconfigService {
  const _FakeKubeconfigService({required this.resolveAuthResult});

  final KubeconfigAuth? resolveAuthResult;

  @override
  Future<KubeconfigAuth?> resolveAuth({
    required String configPath,
    required String contextName,
  }) async {
    return resolveAuthResult;
  }
}

class _FakeKubernetesApiClient extends KubernetesApiClient {
  _FakeKubernetesApiClient({
    this.responses = const {},
    this.errors = const {},
  });

  final Map<String, Map<String, dynamic>> responses;
  final Map<String, Object> errors;

  @override
  Future<Map<String, dynamic>> getJson({
    required String server,
    required String path,
    Map<String, String>? query,
    required KubeconfigAuth auth,
  }) async {
    final error = errors[path];
    if (error != null) {
      throw error;
    }
    return responses[path] ?? const {'items': []};
  }
}
