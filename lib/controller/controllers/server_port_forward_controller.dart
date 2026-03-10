import 'package:cwatch/view/features/servers/server_workspace_ui_adapter.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/services_infra/logging/app_logger.dart';
import 'package:cwatch/model/services_infra/port_forwarding/port_forward_service.dart';
import 'package:cwatch/model/services_infra/settings/app_settings_controller.dart';
import 'package:cwatch/model/services_infra/ssh/builtin/builtin_ssh_key_service.dart';

class ServerPortForwardController {
  ServerPortForwardController({
    required this.portForwardService,
    required this.settingsController,
    required this.keyService,
    required this.uiAdapter,
  });

  final PortForwardService portForwardService;
  final AppSettingsController settingsController;
  final BuiltInSshKeyService keyService;
  final ServerWorkspaceUiAdapter uiAdapter;

  Future<void> openDialog(SshHost host) async {
    final active = portForwardService.forwardsForHost(host).toList();
    final hostKeyBindings =
        settingsController.settings.builtinSshHostKeyBindings;
    final initial = active.isNotEmpty
        ? active.expand((f) => f.requests.map((r) => r.copy())).toList()
        : [
            PortForwardRequest(
              remoteHost: '127.0.0.1',
              remotePort: 0,
              localPort: 0,
              label: 'Mapping 1',
            ),
          ];
    final result = await uiAdapter.promptPortForwardDialog(
      title: 'Port forwarding (${host.name})',
      requests: initial,
      portValidator: portForwardService.isPortAvailable,
      active: active,
    );
    if (result == null || result.isEmpty) return;
    try {
      await portForwardService.startForward(
        host: host,
        requests: result,
        settingsController: settingsController,
        builtInKeyService: keyService,
        hostKeyBindings: hostKeyBindings,
        authCoordinator: uiAdapter.buildSshAuthCoordinator(
          keyService: keyService,
        ),
      );
      final summary = result
          .map((r) => '${r.localPort}->${r.remotePort}')
          .join(', ');
      uiAdapter.showSnackBar('Forwarding $summary for ${host.name}.');
    } catch (error, stackTrace) {
      AppLogger().warn(
        'Failed to start port forwarding for ${host.name}',
        tag: 'Servers',
        error: error,
        stackTrace: stackTrace,
      );
      uiAdapter.showSnackBar('Port forward failed: $error');
    }
  }
}
