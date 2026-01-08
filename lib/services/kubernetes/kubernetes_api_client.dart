import 'dart:convert';
import 'dart:io';

import 'package:cwatch/services/kubernetes/kubeconfig_service.dart';
import 'package:cwatch/services/logging/app_logger.dart';

class KubernetesApiClient {
  KubernetesApiClient();

  Future<Map<String, dynamic>> getJson({
    required String server,
    required String path,
    Map<String, String>? query,
    required KubeconfigAuth auth,
  }) async {
    final uri = _buildUri(server, path, query);
    final client = _buildClient(auth);
    final logger = AppLogger.remote(tag: 'K8s API', source: 'k8s-api');
    final stopwatch = Stopwatch()..start();
    logger.debug(
      'Requesting ${uri.toString()}',
      remote: RemoteCommandDetails(
        operation: 'GET',
        command: uri.toString(),
        output: '',
        contextLabel: auth.contextName,
      ),
    );
    try {
      final request = await client.getUrl(uri);
      if (auth.token != null) {
        request.headers.set('Authorization', 'Bearer ${auth.token}');
      }
      request.headers.set('Accept', 'application/json');
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      stopwatch.stop();
      final output = _formatOutput(response.statusCode, body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        logger.warn(
          'API request failed in ${stopwatch.elapsedMilliseconds}ms',
          remote: RemoteCommandDetails(
            operation: 'GET',
            command: uri.toString(),
            output: output,
            contextLabel: auth.contextName,
          ),
        );
        throw HttpException(
          'HTTP ${response.statusCode}: ${response.reasonPhrase}',
          uri: uri,
        );
      }
      logger.debug(
        'API request completed in ${stopwatch.elapsedMilliseconds}ms',
        remote: RemoteCommandDetails(
          operation: 'GET',
          command: uri.toString(),
          output: output,
          contextLabel: auth.contextName,
        ),
      );
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      throw const FormatException('Unexpected JSON response format');
    } catch (error) {
      if (stopwatch.isRunning) {
        stopwatch.stop();
      }
      logger.error(
        'API request error after ${stopwatch.elapsedMilliseconds}ms',
        error: error,
        remote: RemoteCommandDetails(
          operation: 'GET',
          command: uri.toString(),
          output: 'Error: $error',
          contextLabel: auth.contextName,
        ),
      );
      rethrow;
    } finally {
      client.close(force: true);
    }
  }

  Uri _buildUri(String server, String path, Map<String, String>? query) {
    final base = Uri.parse(server);
    return base.replace(
      path: _normalizePath(base.path, path),
      queryParameters: query,
    );
  }

  String _normalizePath(String basePath, String nextPath) {
    if (basePath.isEmpty || basePath == '/') {
      return nextPath.startsWith('/') ? nextPath : '/$nextPath';
    }
    final trimmed = basePath.endsWith('/')
        ? basePath.substring(0, basePath.length - 1)
        : basePath;
    final relative = nextPath.startsWith('/')
        ? nextPath.substring(1)
        : nextPath;
    return '$trimmed/$relative';
  }

  HttpClient _buildClient(KubeconfigAuth auth) {
    final context = SecurityContext();
    if (auth.certificateAuthorityData != null) {
      context.setTrustedCertificatesBytes(auth.certificateAuthorityData!);
    }
    if (auth.clientCertificateData != null && auth.clientKeyData != null) {
      context.useCertificateChainBytes(auth.clientCertificateData!);
      context.usePrivateKeyBytes(auth.clientKeyData!);
    }
    final client = HttpClient(context: context);
    if (auth.insecureSkipTlsVerify) {
      client.badCertificateCallback = (_, __, ___) => true;
    }
    return client;
  }

  String _formatOutput(int statusCode, String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      return 'HTTP $statusCode';
    }
    final normalized = trimmed.replaceAll(RegExp(r'\s+'), ' ');
    const maxLength = 400;
    final snippet = normalized.length > maxLength
        ? '${normalized.substring(0, maxLength)}…'
        : normalized;
    return 'HTTP $statusCode: $snippet';
  }
}
