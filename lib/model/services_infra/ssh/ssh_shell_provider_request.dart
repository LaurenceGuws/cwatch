import 'package:cwatch/model/models/ssh_client_backend.dart';

class SshShellProviderRequest {
  const SshShellProviderRequest({
    required this.backend,
    required this.debugMode,
    required this.bindingsSignature,
    this.connectTimeout,
  });

  final SshClientBackend backend;
  final bool debugMode;
  final String bindingsSignature;
  final Duration? connectTimeout;

  bool get usesBuiltIn => backend == SshClientBackend.builtin;

  String get cacheSignature {
    final base = [backend.name, debugMode, bindingsSignature].join('|');
    if (connectTimeout == null) {
      return base;
    }
    return '$base|timeout:${connectTimeout!.inMilliseconds}';
  }

  String get settingsSignature => [backend.name, debugMode, bindingsSignature].join('|');
}
