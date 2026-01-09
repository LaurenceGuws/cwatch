import 'package:cwatch/models/ssh_host.dart';
import 'package:cwatch/modules/servers/ui/server_tab_builder.dart';
import 'package:cwatch/services/filesystem/explorer_trash_manager.dart';
import 'package:cwatch/services/settings/app_settings_controller.dart';
import 'package:cwatch/services/ssh/builtin/builtin_ssh_key_service.dart';
import 'package:cwatch/services/ssh/remote_shell_service.dart';

class ServerTabBuilderBinding {
  const ServerTabBuilderBinding();

  ServerTabBuilder create({
    required AppSettingsController settingsController,
    required ExplorerTrashManager trashManager,
    required RemoteShellService Function(SshHost host) shellServiceForHost,
    required BuiltInSshKeyService keyService,
    required Future<List<SshHost>> hostsFuture,
  }) {
    return ServerTabBuilder(
      settingsController: settingsController,
      trashManager: trashManager,
      shellServiceForHost: shellServiceForHost,
      keyService: keyService,
      hostsFuture: hostsFuture,
    );
  }
}
