import 'package:cwatch/model/services_infra/settings/app_settings_controller.dart';
import 'package:cwatch/model/services_infra/ssh/builtin/builtin_ssh_key_service.dart';
import 'package:cwatch/model/services_infra/ssh/ssh_auth_coordinator.dart';
import 'package:cwatch/model/services_infra/ssh/ssh_shell_factory.dart';

class SshShellFactoryBinding {
  const SshShellFactoryBinding();

  SshShellFactory create({
    required AppSettingsController settingsController,
    required BuiltInSshKeyService keyService,
    SshAuthCoordinator? authCoordinator,
  }) {
    return SshShellFactory(
      settingsController: settingsController,
      keyService: keyService,
      authCoordinator: authCoordinator,
    );
  }
}
