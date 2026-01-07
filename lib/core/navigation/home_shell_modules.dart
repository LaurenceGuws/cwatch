import '../../models/ssh_host.dart';
import '../../modules/debug_logs/view.dart';
import '../../modules/docker/view.dart';
import '../../modules/kubernetes/view.dart';
import '../../modules/sandbox/view.dart';
import '../../modules/servers/view.dart';
import '../../modules/settings/view.dart';
import '../../modules/wsl/view.dart';
import '../../services/settings/app_settings_controller.dart';
import '../../services/ssh/builtin/builtin_ssh_key_service.dart';
import '../../services/ssh/ssh_shell_factory.dart';
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
    modules.add(const WslModule());
  }
  modules.addAll([
    DockerModule(
      hostsFuture: hostsFuture,
      settingsController: settingsController,
      keyService: keyService,
      shellFactory: shellFactory,
    ),
    KubernetesModule(settingsController: settingsController),
    SandboxModule(settingsController: settingsController),
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
