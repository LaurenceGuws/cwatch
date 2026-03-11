import 'package:cwatch/controller/adapters/port_forward_ui.dart';
import 'package:cwatch/model/models/docker_container.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/services_infra/logging/app_logger.dart';
import 'package:cwatch/model/services_infra/port_forwarding/port_forward_service.dart';
import 'package:cwatch/model/services_infra/settings/app_settings_controller.dart';
import 'package:cwatch/model/services_infra/ssh/builtin/builtin_ssh_key_service.dart';

class DockerPortForwardController {
  DockerPortForwardController({
    required this.portForwardService,
    required this.settingsController,
    required this.keyService,
    required this.ui,
    required this.remoteHost,
    required this.cachedContainers,
  });

  final PortForwardService portForwardService;
  final AppSettingsController settingsController;
  final BuiltInSshKeyService keyService;
  final PortForwardUi ui;
  final SshHost? remoteHost;
  final Iterable<DockerContainer> Function() cachedContainers;

  bool get _supportsForwarding => remoteHost != null;

  List<int> extractPorts(String raw) {
    final parts = raw
        .split(',')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty);
    final ports = <int>{};
    for (final part in parts) {
      final arrowIndex = part.indexOf('->');
      if (arrowIndex != -1) {
        final hostSide = part.substring(0, arrowIndex);
        final segments = hostSide.split(':');
        final candidate = segments.isNotEmpty ? segments.last : hostSide;
        final parsed = int.tryParse(
          RegExp(r'([0-9]+)').stringMatch(candidate) ?? '',
        );
        if (parsed != null) {
          ports.add(parsed);
          continue;
        }
      }
      final startMatch = RegExp(r'^([0-9]+)').firstMatch(part);
      if (startMatch != null) {
        ports.add(int.parse(startMatch.group(1)!));
      }
    }
    final list = ports.toList()..sort();
    return list;
  }

  Future<int> pickLocalPort(Set<int> reserved, int preferred) async {
    var candidate = preferred;
    while (candidate < 65535) {
      if (!reserved.contains(candidate) &&
          await portForwardService.isPortAvailable(candidate)) {
        return candidate;
      }
      candidate += 1;
    }
    throw Exception('No free local ports available for $preferred');
  }

  Future<void> forwardContainerPorts({
    required DockerContainer container,
  }) async {
    final host = remoteHost;
    if (!_supportsForwarding || host == null) {
      return;
    }
    final detected = extractPorts(container.ports);
    final activeForwards = portForwardService.forwardsForHost(host).toList();
    if (detected.isEmpty) {
      ui.showSnackBar('No published ports detected.');
      return;
    }
    final requests = <PortForwardRequest>[];
    for (final port in detected) {
      final existing = activeForwards
          .expand((f) => f.requests)
          .firstWhere(
            (r) => r.remotePort == port,
            orElse: () => PortForwardRequest(
              remoteHost: '127.0.0.1',
              remotePort: 0,
              localPort: 0,
            ),
          );
      final local = existing.remotePort == port && existing.localPort > 0
          ? existing.localPort
          : await portForwardService.suggestLocalPort(port);
      AppLogger().debug(
        'Forward default for ${container.id}: remote=$port local=$local '
        '(existingMatch=${existing.remotePort == port && existing.localPort > 0})',
        tag: 'PortForward',
      );
      requests.add(
        PortForwardRequest(
          remoteHost: '127.0.0.1',
          remotePort: port,
          localPort: local,
          label: container.name.isNotEmpty ? container.name : container.id,
        ),
      );
    }
    final result = await ui.showPortForwardDialog(
      title:
          'Forward ports (${container.name.isNotEmpty ? container.name : container.id})',
      requests: requests,
      portValidator: portForwardService.isPortAvailable,
      active: activeForwards,
    );
    if (result == null || result.isEmpty) return;
    await _startForward(
      host: host,
      requests: result,
      successMessage: 'Forwarding ${_summary(result)} via SSH.',
      failureLogTarget: container.name,
    );
  }

  Future<void> stopForwardsForHost() async {
    final host = remoteHost;
    if (!_supportsForwarding || host == null) return;
    final forwards = portForwardService.forwardsForHost(host).toList();
    if (forwards.isEmpty) {
      ui.showSnackBar('No active forwards.');
      return;
    }
    for (final forward in forwards) {
      await portForwardService.stopForward(forward.id);
    }
    ui.showSnackBar('Stopped active port forwards.');
  }

  Future<void> forwardComposePorts({required String project}) async {
    final host = remoteHost;
    if (!_supportsForwarding || host == null) return;
    final ports = <int>{};
    for (final container in cachedContainers()) {
      if (container.composeProject == project) {
        ports.addAll(extractPorts(container.ports));
      }
    }
    final sorted = ports.toList()..sort();
    if (sorted.isEmpty) {
      ui.showSnackBar('No published ports detected.');
      return;
    }
    final portServices = <int, Set<String>>{};
    for (final container in cachedContainers()) {
      if (container.composeProject != project) continue;
      final serviceName = (container.composeService?.isNotEmpty ?? false)
          ? container.composeService!
          : (container.name.isNotEmpty ? container.name : project);
      final containerPorts = extractPorts(container.ports);
      for (final port in containerPorts) {
        portServices.putIfAbsent(port, () => <String>{}).add(serviceName);
      }
    }

    final activeForwards = portForwardService.forwardsForHost(host).toList();
    final requests = <PortForwardRequest>[];
    final reservedLocals = activeForwards
        .expand((f) => f.requests.map((r) => r.localPort))
        .where((p) => p > 0)
        .toSet();
    for (final port in sorted) {
      final existing = activeForwards
          .expand((f) => f.requests)
          .firstWhere(
            (r) => r.remotePort == port,
            orElse: () => PortForwardRequest(
              remoteHost: '127.0.0.1',
              remotePort: 0,
              localPort: 0,
            ),
          );
      final local = existing.remotePort == port && existing.localPort > 0
          ? existing.localPort
          : await pickLocalPort(reservedLocals, port);
      reservedLocals.add(local);
      AppLogger().debug(
        'Compose $project forward default: remote=$port local=$local '
        '(existingMatch=${existing.remotePort == port && existing.localPort > 0})',
        tag: 'PortForward',
      );
      final services = portServices[port];
      final label = (services != null && services.isNotEmpty)
          ? services.join(', ')
          : project;
      requests.add(
        PortForwardRequest(
          remoteHost: '127.0.0.1',
          remotePort: port,
          localPort: local,
          label: label,
        ),
      );
    }
    final result = await ui.showPortForwardDialog(
      title: 'Forward ports (Compose $project)',
      requests: requests,
      portValidator: portForwardService.isPortAvailable,
      active: activeForwards,
    );
    if (result == null || result.isEmpty) return;
    await _startForward(
      host: host,
      requests: result,
      successMessage: 'Forwarding ${_summary(result)} for $project.',
      failureLogTarget: project,
    );
  }

  Future<void> _startForward({
    required SshHost host,
    required List<PortForwardRequest> requests,
    required String successMessage,
    required String failureLogTarget,
  }) async {
    final hostKeyBindings =
        settingsController.settings.sshPreferences.builtinHostKeyBindings;
    try {
      await portForwardService.startForward(
        host: host,
        requests: requests,
        settingsController: settingsController,
        builtInKeyService: keyService,
        hostKeyBindings: hostKeyBindings,
      );
      ui.showSnackBar(successMessage);
    } catch (error, stackTrace) {
      AppLogger().warn(
        'Failed to create port forward for $failureLogTarget',
        tag: 'Docker',
        error: error,
        stackTrace: stackTrace,
      );
      ui.showSnackBar('Port forward failed: $error');
    }
  }

  String _summary(List<PortForwardRequest> requests) {
    return requests.map((r) => '${r.localPort}->${r.remotePort}').join(', ');
  }
}
