import 'dart:convert';

import 'package:cwatch/model/models/kubernetes_backend.dart';
import 'package:cwatch/model/models/kubernetes/kubeconfig_context.dart';
import 'package:cwatch/model/services_infra/kubernetes/kubeconfig_service.dart';
import 'package:cwatch/model/services_infra/kubernetes/kubectl_service.dart';
import 'package:cwatch/model/services_infra/kubernetes/kubernetes_api_client.dart';
import 'package:cwatch/model/services_infra/kubernetes/kubernetes_dashboard_collection_result.dart';

class KubernetesDashboardCollector {
  KubernetesDashboardCollector({
    KubectlService? kubectl,
    KubeconfigService? kubeconfig,
    KubernetesApiClient? apiClient,
  }) : _kubectl = kubectl ?? const KubectlService(),
       _kubeconfig = kubeconfig ?? const KubeconfigService(),
       _apiClient = apiClient ?? KubernetesApiClient();

  final KubectlService _kubectl;
  final KubeconfigService _kubeconfig;
  final KubernetesApiClient _apiClient;

  Future<KubernetesDashboardCollectionResult> collect({
    required KubernetesBackend backend,
    required KubeconfigContext context,
  }) async {
    if (backend == KubernetesBackend.api) {
      return _collectApi(context: context, backend: backend);
    }
    return _collectCli(context: context, backend: backend);
  }

  Future<KubernetesDashboardCollectionResult> _collectApi({
    required KubeconfigContext context,
    required KubernetesBackend backend,
  }) async {
    final auth = await _kubeconfig.resolveAuth(
      configPath: context.configPath,
      contextName: context.name,
    );
    if (auth == null) {
      return KubernetesDashboardCollectionResult(
        backend: backend,
        context: context,
        clusterName: context.cluster ?? 'Cluster',
        namespace: context.namespace,
        server: context.server,
        nodes: const {},
        namespaces: const {},
        deployments: const {},
        pods: const {},
        services: const {},
        events: const {},
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

    return KubernetesDashboardCollectionResult(
      backend: backend,
      context: context,
      clusterName: context.cluster ?? auth.clusterName,
      namespace: context.namespace ?? auth.namespace,
      server: context.server ?? auth.server,
      nodes: nodesJson,
      namespaces: namespacesJson,
      deployments: deploymentsJson,
      pods: podsJson,
      services: servicesJson,
      events: eventsJson,
      warnings: warnings,
    );
  }

  Future<KubernetesDashboardCollectionResult> _collectCli({
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

    return KubernetesDashboardCollectionResult(
      backend: backend,
      context: context,
      clusterName: context.cluster ?? 'Cluster',
      namespace: context.namespace,
      server: context.server,
      nodes: nodesJson,
      namespaces: namespacesJson,
      deployments: deploymentsJson,
      pods: podsJson,
      services: servicesJson,
      events: eventsJson,
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
    } catch (_) {
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
    } catch (_) {
      warnings.add('Failed to load $label.');
    }
    return const {};
  }
}
