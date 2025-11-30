import 'package:flutter/widgets.dart';

import '../../core/navigation/shell_module.dart';
import 'package:cwatch/models/ssh_host.dart';
import 'package:cwatch/services/settings/app_settings_controller.dart';
import 'package:cwatch/services/ssh/builtin/builtin_ssh_vault.dart';
import 'package:cwatch/services/ssh/remote_command_logging.dart';
import '../../shared/theme/nerd_fonts.dart';
import 'ui/docker_view.dart';

class DockerModule extends ShellModuleView {
  DockerModule({
    required this.hostsFuture,
    required this.settingsController,
    required this.builtInVault,
    required this.commandLog,
  });

  final Future<List<SshHost>> hostsFuture;
  final AppSettingsController settingsController;
  final BuiltInSshVault builtInVault;
  final RemoteCommandLogController commandLog;

  @override
  String get id => 'docker';

  @override
  String get label => 'Docker';

  @override
  NerdIcon get icon => NerdIcon.docker;

  @override
  Widget build(BuildContext context, Widget leading) {
    return DockerView(
      leading: leading,
      hostsFuture: hostsFuture,
      settingsController: settingsController,
      builtInVault: builtInVault,
      commandLog: commandLog,
    );
  }
}
