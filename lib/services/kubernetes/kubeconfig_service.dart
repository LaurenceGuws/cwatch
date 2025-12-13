import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

class KubeconfigContext {
  const KubeconfigContext({
    required this.name,
    required this.cluster,
    required this.user,
    required this.namespace,
    required this.server,
    required this.configPath,
    required this.isCurrent,
  });

  final String name;
  final String? cluster;
  final String? user;
  final String? namespace;
  final String? server;
  final String configPath;
  final bool isCurrent;
}

class KubeconfigService {
  const KubeconfigService();

  Future<List<KubeconfigContext>> listContexts(List<String> configPaths) async {
    final resolved = await Future.wait(configPaths.map(_resolveConfigPath));
    final contexts = <KubeconfigContext>[];
    for (final entry in resolved) {
      final configPath = entry.path;
      final doc = entry.map;
      if (doc == null) {
        continue;
      }
      final currentContext = _string(doc['current-context']);
      final clusters = _toNameLookup(doc['clusters']);
      final contextsList = doc['contexts'];
      if (contextsList is YamlList) {
        for (final rawContext in contextsList) {
          if (rawContext is! YamlMap) continue;
          final name = _string(rawContext['name']);
          final detail = rawContext['context'];
          if (name == null || detail is! YamlMap) continue;
          final clusterName = _string(detail['cluster']);
          final userName = _string(detail['user']);
          final namespace = _string(detail['namespace']);
          final clusterInfo = clusterName != null
              ? clusters[clusterName]
              : null;
          final server = clusterInfo != null
              ? _string(clusterInfo['server'])
              : null;
          contexts.add(
            KubeconfigContext(
              name: name,
              cluster: clusterName,
              user: userName,
              namespace: namespace,
              server: server,
              configPath: configPath,
              isCurrent: currentContext != null && currentContext == name,
            ),
          );
        }
      }
    }
    return contexts;
  }

  Future<_PathAndDocument> _resolveConfigPath(String rawPath) async {
    final expanded = _expandPath(rawPath.trim());
    if (expanded.isEmpty) {
      return const _PathAndDocument(path: '', map: null);
    }
    final file = File(expanded);
    if (!await file.exists()) {
      return _PathAndDocument(path: expanded, map: null);
    }
    try {
      final contents = await file.readAsString();
      final doc = loadYaml(contents);
      if (doc is YamlMap) {
        return _PathAndDocument(path: expanded, map: doc);
      }
    } catch (_) {
      // ignore parse errors
    }
    return _PathAndDocument(path: expanded, map: null);
  }

  Map<String, YamlMap> _toNameLookup(dynamic value) {
    final lookup = <String, YamlMap>{};
    if (value is YamlList) {
      for (final entry in value) {
        if (entry is YamlMap) {
          final name = _string(entry['name']);
          final detail = entry['cluster'] ?? entry['user'];
          if (name != null && detail is YamlMap) {
            lookup[name] = detail;
          }
        }
      }
    }
    return lookup;
  }

  String _expandPath(String raw) {
    if (raw.isEmpty) return '';
    if (raw.startsWith('~')) {
      final home = Platform.environment['HOME'];
      if (home != null && home.isNotEmpty) {
        return path.join(home, raw.substring(1));
      }
    }
    return raw;
  }

  String? _string(dynamic value) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return null;
  }
}

class _PathAndDocument {
  const _PathAndDocument({required this.path, required this.map});

  final String path;
  final YamlMap? map;
}
