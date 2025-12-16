import 'dart:io';

import 'package:path/path.dart' as path;

import 'package:cwatch/models/app_settings.dart';
import 'package:cwatch/services/kubernetes/kubeconfig_service.dart';

class KubernetesContextController {
  KubernetesContextController({KubeconfigService? kubeconfig})
    : _kubeconfig = kubeconfig ?? const KubeconfigService();

  final KubeconfigService _kubeconfig;

  Future<List<KubeconfigContext>>? contextsFuture;
  List<KubeconfigContext> cachedContexts = const [];

  Future<List<KubeconfigContext>> loadContexts(List<String> configPaths) async {
    contextsFuture = _kubeconfig.listContexts(configPaths);
    final contexts = await contextsFuture!;
    cachedContexts = contexts;
    return contexts;
  }

  List<String> resolveConfigPaths(AppSettings settings) {
    if (settings.kubernetesConfigPaths.isNotEmpty) {
      return settings.kubernetesConfigPaths;
    }
    final env = Platform.environment['KUBECONFIG']?.trim();
    if (env != null && env.isNotEmpty) {
      final separator = Platform.isWindows ? ';' : ':';
      return env
          .split(separator)
          .map((entry) => entry.trim())
          .where((entry) => entry.isNotEmpty)
          .toList();
    }
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'];
    if (home != null && home.isNotEmpty) {
      return [path.join(home, '.kube', 'config')];
    }
    return const [];
  }

  Map<String, List<KubeconfigContext>> groupByConfigPath(
    List<KubeconfigContext> contexts,
  ) {
    final grouped = <String, List<KubeconfigContext>>{};
    for (final ctx in contexts) {
      grouped.putIfAbsent(ctx.configPath, () => []).add(ctx);
    }
    for (final entry in grouped.entries) {
      entry.value.sort((a, b) => a.name.compareTo(b.name));
    }
    return grouped;
  }

  bool contextEquals(KubeconfigContext a, KubeconfigContext b) {
    return a.name == b.name &&
        a.cluster == b.cluster &&
        a.user == b.user &&
        a.namespace == b.namespace &&
        a.server == b.server &&
        a.configPath == b.configPath &&
        a.isCurrent == b.isCurrent;
  }

  KubeconfigContext? findContext(
    List<KubeconfigContext> contexts,
    String name,
    String configPath,
  ) {
    for (final context in contexts) {
      if (context.name == name && context.configPath == configPath) {
        return context;
      }
    }
    return null;
  }
}
