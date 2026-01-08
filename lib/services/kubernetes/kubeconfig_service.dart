import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

import '../logging/app_logger.dart';

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

class KubeconfigAuth {
  const KubeconfigAuth({
    required this.server,
    required this.contextName,
    required this.clusterName,
    required this.userName,
    required this.namespace,
    required this.insecureSkipTlsVerify,
    this.token,
    this.certificateAuthorityData,
    this.clientCertificateData,
    this.clientKeyData,
    this.warnings = const [],
  });

  final String server;
  final String contextName;
  final String clusterName;
  final String? userName;
  final String? namespace;
  final bool insecureSkipTlsVerify;
  final String? token;
  final List<int>? certificateAuthorityData;
  final List<int>? clientCertificateData;
  final List<int>? clientKeyData;
  final List<String> warnings;
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

  Future<KubeconfigAuth?> resolveAuth({
    required String configPath,
    required String contextName,
  }) async {
    final resolved = await _resolveConfigPath(configPath);
    final doc = resolved.map;
    if (doc == null) {
      return null;
    }

    final contextsList = doc['contexts'];
    YamlMap? contextDetail;
    if (contextsList is YamlList) {
      for (final rawContext in contextsList) {
        if (rawContext is! YamlMap) continue;
        final name = _string(rawContext['name']);
        if (name != contextName) continue;
        final detail = rawContext['context'];
        if (detail is YamlMap) {
          contextDetail = detail;
        }
        break;
      }
    }
    if (contextDetail == null) {
      return null;
    }

    final clusterName = _string(contextDetail['cluster']);
    final userName = _string(contextDetail['user']);
    final namespace = _string(contextDetail['namespace']);
    if (clusterName == null) {
      return null;
    }

    final clusters = _toNameLookup(doc['clusters']);
    final users = _toNameLookup(doc['users']);
    final clusterInfo = clusters[clusterName];
    final userInfo = userName != null ? users[userName] : null;
    final server = clusterInfo != null ? _string(clusterInfo['server']) : null;
    if (server == null) {
      return null;
    }

    final warnings = <String>[];
    final insecureSkipTlsVerify =
        (clusterInfo?['insecure-skip-tls-verify'] as bool?) ?? false;

    final certificateAuthorityData = await _loadBytes(
      clusterInfo?['certificate-authority-data'],
      clusterInfo?['certificate-authority'],
      resolved.path,
    );

    if (certificateAuthorityData == null && !insecureSkipTlsVerify) {
      warnings.add('Missing certificate authority data for $clusterName.');
    }

    String? token;
    if (userInfo != null) {
      token = _string(userInfo['token']);
      final tokenFile = _string(userInfo['tokenFile']);
      if (token == null && tokenFile != null) {
        token = await _readTokenFile(tokenFile, resolved.path);
      }
      if (userInfo['exec'] != null) {
        warnings.add('exec-based auth is not supported yet.');
      }
      if (userInfo['auth-provider'] != null) {
        warnings.add('auth-provider configuration is not supported yet.');
      }
    }

    final clientCertificateData = await _loadBytes(
      userInfo?['client-certificate-data'],
      userInfo?['client-certificate'],
      resolved.path,
    );
    final clientKeyData = await _loadBytes(
      userInfo?['client-key-data'],
      userInfo?['client-key'],
      resolved.path,
    );

    return KubeconfigAuth(
      server: server,
      contextName: contextName,
      clusterName: clusterName,
      userName: userName,
      namespace: namespace,
      insecureSkipTlsVerify: insecureSkipTlsVerify,
      token: token,
      certificateAuthorityData: certificateAuthorityData,
      clientCertificateData: clientCertificateData,
      clientKeyData: clientKeyData,
      warnings: warnings,
    );
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
    } catch (error, stackTrace) {
      AppLogger().warn(
        'Failed to parse kubeconfig at $expanded',
        tag: 'Kubeconfig',
        error: error,
        stackTrace: stackTrace,
      );
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

  Future<List<int>?> _loadBytes(
    dynamic inlineData,
    dynamic filePath,
    String configPath,
  ) async {
    final inline = _string(inlineData);
    if (inline != null) {
      try {
        return base64Decode(inline);
      } catch (_) {
        return null;
      }
    }
    final pathValue = _string(filePath);
    if (pathValue == null) return null;
    final resolved = _resolvePath(pathValue, configPath);
    if (resolved == null) return null;
    final file = File(resolved);
    if (!await file.exists()) return null;
    try {
      return await file.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  Future<String?> _readTokenFile(String tokenFile, String configPath) async {
    final resolved = _resolvePath(tokenFile, configPath);
    if (resolved == null) return null;
    final file = File(resolved);
    if (!await file.exists()) return null;
    try {
      final contents = await file.readAsString();
      return _string(contents);
    } catch (_) {
      return null;
    }
  }

  String? _resolvePath(String rawPath, String configPath) {
    final expanded = _expandPath(rawPath);
    if (expanded.isEmpty) return null;
    if (path.isAbsolute(expanded)) {
      return expanded;
    }
    return path.normalize(path.join(path.dirname(configPath), expanded));
  }
}

class _PathAndDocument {
  const _PathAndDocument({required this.path, required this.map});

  final String path;
  final YamlMap? map;
}
