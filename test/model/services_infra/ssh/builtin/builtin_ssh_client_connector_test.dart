import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/services_infra/ssh/builtin/builtin_ssh_client_connector.dart';
import 'package:cwatch/model/services_infra/ssh/builtin/builtin_identity_manager.dart';
import 'package:cwatch/model/services_infra/ssh/builtin/builtin_ssh_vault.dart';
import 'package:cwatch/model/services_infra/ssh/builtin/builtin_ssh_key_store.dart';
import 'package:cwatch/model/services_infra/ssh/known_hosts_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final connector = BuiltInSshClientConnector(
    identityManager: BuiltInSshIdentityManager(
      vault: BuiltInSshVault(keyStore: BuiltInSshKeyStore()),
      hostKeyBindings: const {},
    ),
    knownHostsStore: const KnownHostsStore(),
    connectTimeout: const Duration(seconds: 10),
  );

  test('hostLabel omits port 22', () {
    const host = SshHost(
      name: 'example',
      hostname: 'example.local',
      port: 22,
      available: true,
    );

    expect(connector.hostLabel(host), 'example.local');
  });

  test('hostLabel includes non-default port', () {
    const host = SshHost(
      name: 'example',
      hostname: 'example.local',
      port: 2222,
      available: true,
    );

    expect(connector.hostLabel(host), '[example.local]:2222');
  });

  test('fingerprintHex formats lowercase colon-delimited hex', () {
    expect(
      connector.fingerprintHex([0, 10, 255]),
      '00:0a:ff',
    );
  });
}
