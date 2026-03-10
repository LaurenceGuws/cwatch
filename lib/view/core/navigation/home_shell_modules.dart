import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/services_infra/settings/app_settings_controller.dart';
import 'package:cwatch/model/services_infra/ssh/builtin/builtin_ssh_key_service.dart';
import 'package:cwatch/model/services_infra/ssh/ssh_shell_factory.dart';
import 'feature_modules.dart';
import 'shell_module.dart';

List<ShellModuleView> buildHomeShellModules({
  required Future<List<SshHost>> hostsFuture,
  required AppSettingsController settingsController,
  required BuiltInSshKeyService keyService,
  required SshShellFactory shellFactory,
  required bool isWindows,
}) {
  final modules = <ShellModuleView>[
    ServersModule(
      hostsFuture: hostsFuture,
      settingsController: settingsController,
      keyService: keyService,
      shellFactory: shellFactory,
    ),
  ];
  if (isWindows) {
    modules.add(WslModule(settingsController: settingsController));
  }
  modules.addAll([
    DockerModule(
      hostsFuture: hostsFuture,
      settingsController: settingsController,
      keyService: keyService,
      shellFactory: shellFactory,
    ),
    KubernetesModule(
      settingsController: settingsController,
      keyService: keyService,
      hostsFuture: hostsFuture,
    ),
    DebugLogsModule(settingsController: settingsController),
    SettingsModule(
      controller: settingsController,
      hostsFuture: hostsFuture,
      keyService: keyService,
      shellFactory: shellFactory,
    ),
  ]);
  return modules;
}
