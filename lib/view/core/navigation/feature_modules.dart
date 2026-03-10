import 'package:flutter/widgets.dart';

import 'package:cwatch/model/features/wsl/services/wsl_service.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/services_infra/settings/app_settings_controller.dart';
import 'package:cwatch/model/services_infra/ssh/builtin/builtin_ssh_key_service.dart';
import 'package:cwatch/model/services_infra/ssh/ssh_shell_factory.dart';
import 'package:cwatch/model/shared/theme/nerd_fonts.dart';
import 'package:cwatch/view/features/debug_logs/debug_logs_view.dart';
import 'package:cwatch/view/features/docker/docker_view.dart';
import 'package:cwatch/view/features/kubernetes/kubernetes_context_list.dart';
import 'package:cwatch/view/features/servers/server_workspace_view.dart';
import 'package:cwatch/view/features/settings/settings/settings_view.dart';
import 'package:cwatch/view/features/wsl/wsl_view.dart';

import 'shell_module.dart';

class ServersModule extends ShellModuleView {
  ServersModule({
    required this.hostsFuture,
    required this.settingsController,
    required this.keyService,
    required this.shellFactory,
  });

  final Future<List<SshHost>> hostsFuture;
  final AppSettingsController settingsController;
  final BuiltInSshKeyService keyService;
  final SshShellFactory shellFactory;

  @override
  String get id => 'servers';

  @override
  String get label => 'Servers';

  @override
  NerdIcon get icon => NerdIcon.servers;

  @override
  Widget build(BuildContext context, Widget leading) {
    return ServerWorkspaceView(
      moduleId: id,
      hostsFuture: hostsFuture,
      settingsController: settingsController,
      keyService: keyService,
      shellFactory: shellFactory,
      leading: leading,
    );
  }
}

class DockerModule extends ShellModuleView {
  DockerModule({
    required this.hostsFuture,
    required this.settingsController,
    required this.keyService,
    required this.shellFactory,
  });

  final Future<List<SshHost>> hostsFuture;
  final AppSettingsController settingsController;
  final BuiltInSshKeyService keyService;
  final SshShellFactory shellFactory;

  @override
  String get id => 'docker';

  @override
  String get label => 'Docker';

  @override
  NerdIcon get icon => NerdIcon.docker;

  @override
  Widget build(BuildContext context, Widget leading) {
    return DockerView(
      moduleId: id,
      leading: leading,
      hostsFuture: hostsFuture,
      settingsController: settingsController,
      keyService: keyService,
      shellFactory: shellFactory,
    );
  }
}

class KubernetesModule extends ShellModuleView {
  KubernetesModule({
    required this.settingsController,
    required this.keyService,
    required this.hostsFuture,
  });

  final AppSettingsController settingsController;
  final BuiltInSshKeyService keyService;
  final Future<List<SshHost>> hostsFuture;

  @override
  String get id => 'kubernetes';

  @override
  String get label => 'Kubernetes';

  @override
  NerdIcon get icon => NerdIcon.kubernetes;

  @override
  Widget build(BuildContext context, Widget leading) {
    return KubernetesContextList(
      moduleId: id,
      leading: leading,
      settingsController: settingsController,
      keyService: keyService,
      hostsFuture: hostsFuture,
    );
  }
}

class SettingsModule extends ShellModuleView {
  SettingsModule({
    required this.controller,
    required this.hostsFuture,
    required this.keyService,
    required this.shellFactory,
  });

  final AppSettingsController controller;
  final Future<List<SshHost>> hostsFuture;
  final BuiltInSshKeyService keyService;
  final SshShellFactory shellFactory;

  @override
  String get id => 'settings';

  @override
  String get label => 'Settings';

  @override
  NerdIcon get icon => NerdIcon.settings;

  @override
  bool get isPrimary => false;

  @override
  Widget build(BuildContext context, Widget leading) {
    return SettingsView(
      controller: controller,
      hostsFuture: hostsFuture,
      keyService: keyService,
      shellFactory: shellFactory,
      leading: leading,
    );
  }
}

class WslModule extends ShellModuleView {
  const WslModule({required this.settingsController});

  final AppSettingsController settingsController;

  @override
  String get id => 'wsl';

  @override
  String get label => 'WSL';

  @override
  NerdIcon get icon => NerdIcon.penguin;

  @override
  Widget build(BuildContext context, Widget leading) {
    return WslView(
      moduleId: id,
      leading: leading,
      settingsController: settingsController,
      service: createWslService(),
    );
  }
}

class DebugLogsModule extends ShellModuleView {
  DebugLogsModule({required this.settingsController});

  final AppSettingsController settingsController;

  @override
  String get id => 'debug_logs';

  @override
  String get label => 'Debug Logs';

  @override
  NerdIcon get icon => NerdIcon.alert;

  @override
  bool get isPrimary => false;

  @override
  Widget build(BuildContext context, Widget leading) {
    return DebugLogsView(
      settingsController: settingsController,
      leading: leading,
    );
  }
}
