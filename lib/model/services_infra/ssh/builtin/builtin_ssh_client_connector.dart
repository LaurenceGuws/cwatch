import 'dart:io';

import 'package:cwatch/model/models/ssh_host.dart';
import 'package:dartssh2/dartssh2.dart';

import '../known_hosts_store.dart';
import 'builtin_identity_manager.dart';
import 'builtin_ssh_logging.dart';

class BuiltInSshClientConnector {
  const BuiltInSshClientConnector({
    required BuiltInSshIdentityManager identityManager,
    required KnownHostsStore knownHostsStore,
    required Duration connectTimeout,
  }) : _identityManager = identityManager,
       _knownHostsStore = knownHostsStore,
       _connectTimeout = connectTimeout;

  final BuiltInSshIdentityManager _identityManager;
  final KnownHostsStore _knownHostsStore;
  final Duration _connectTimeout;

  Future<SSHClient> openClient(SshHost host) async {
    final socket = await SSHSocket.connect(
      host.hostname,
      host.port,
      timeout: _connectTimeout,
    );
    final username =
        host.user ??
        Platform.environment['USER'] ??
        Platform.environment['USERNAME'] ??
        'root';
    final identities = await _identityManager.loadIdentities(host);
    logBuiltInSsh(
      'Opening SSH client to ${host.name}@${host.hostname}:${host.port} '
      'with ${identities.length} identities '
      'boundKey=${_identityManager.boundKeyForHost(host.name) ?? 'none'}',
    );
    if (identities.isEmpty) {
      socket.destroy();
      throw Exception('No SSH identity available for ${host.name}');
    }
    return SSHClient(
      socket,
      username: username,
      identities: identities,
      disableHostkeyVerification: false,
      onVerifyHostKey: (type, fingerprint) async {
        final label = _hostLabel(host);
        final fingerprintHex = _fingerprintHex(fingerprint);
        final result = await _knownHostsStore.verifyAndRecord(
          host: label,
          type: type,
          fingerprint: fingerprintHex,
        );
        if (!result.accepted) {
          logBuiltInSsh(
            'Host key verification failed for $label (type=$type fingerprint=$fingerprintHex)',
          );
        } else if (result.added) {
          logBuiltInSsh(
            'Trusted new host key for $label (type=$type fingerprint=$fingerprintHex)',
          );
        }
        return result.accepted;
      },
    );
  }

  String fingerprintHex(List<int> fingerprint) => _fingerprintHex(fingerprint);

  String hostLabel(SshHost host) => _hostLabel(host);

  String _fingerprintHex(List<int> fingerprint) {
    return fingerprint
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join(':');
  }

  String _hostLabel(SshHost host) {
    if (host.port == 22) {
      return host.hostname;
    }
    return '[${host.hostname}]:${host.port}';
  }
}
