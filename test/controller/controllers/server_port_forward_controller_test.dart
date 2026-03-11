import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/controller/adapters/port_forward_ui.dart';
import 'package:cwatch/controller/controllers/server_port_forward_controller.dart';
import 'package:cwatch/model/models/app_settings.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/services_infra/port_forwarding/port_forward_service.dart';
import 'package:cwatch/model/services_infra/settings/app_settings_controller.dart';
import 'package:cwatch/model/services_infra/ssh/builtin/builtin_ssh_key_service.dart';

void main() {
  test('shows success summary after starting server port forward', () async {
    final service = _FakePortForwardService();
    final ui = _FakePortForwardUi(
      result: [
        PortForwardRequest(
          remoteHost: '127.0.0.1',
          remotePort: 8080,
          localPort: 18080,
          label: 'Mapping 1',
        ),
      ],
    );
    final controller = ServerPortForwardController(
      portForwardService: service,
      settingsController: AppSettingsController()..applyOverrides((_) => const AppSettings()),
      keyService: BuiltInSshKeyService(),
      uiAdapter: ui,
    );

    await controller.openDialog(
      const SshHost(
        name: 'prod',
        hostname: 'prod.example',
        port: 22,
        available: true,
      ),
    );

    expect(service.started, hasLength(1));
    expect(ui.messages, contains('Forwarding 18080->8080 for prod.'));
  });
}

class _FakePortForwardUi implements PortForwardUi {
  _FakePortForwardUi({this.result});

  final List<PortForwardRequest>? result;
  final List<String> messages = <String>[];

  @override
  Future<List<PortForwardRequest>?> showPortForwardDialog({
    required String title,
    required List<PortForwardRequest> requests,
    required Future<bool> Function(int port) portValidator,
    required List<ActivePortForward> active,
  }) async {
    return result;
  }

  @override
  void showSnackBar(String message) {
    messages.add(message);
  }
}

class _FakePortForwardService extends PortForwardService {
  final List<List<PortForwardRequest>> started = <List<PortForwardRequest>>[];

  @override
  Future<ActivePortForward> startForward({
    required SshHost host,
    required List<PortForwardRequest> requests,
    AppSettingsController? settingsController,
    BuiltInSshKeyService? builtInKeyService,
    Map<String, String> hostKeyBindings = const {},
    Future<bool> Function(String keyId, String hostName, String? keyLabel)?
    promptDecrypt,
    Duration builtInConnectTimeout = const Duration(seconds: 10),
    dynamic authCoordinator,
  }) async {
    started.add(requests);
    return ActivePortForward(
      id: 'pf-test',
      host: host,
      requests: requests,
      startedAt: DateTime(2026),
      onExit: (code, stderr) {},
      onClose: () async {},
    );
  }
}
