import 'package:flutter/widgets.dart';

import '../../core/navigation/shell_module.dart';
import 'package:cwatch/services/ssh/remote_command_logging.dart';
import 'package:cwatch/services/settings/app_settings_controller.dart';
import 'package:cwatch/models/ssh_host.dart';
import 'ui/servers_list.dart';
import '../../shared/theme/nerd_fonts.dart';
import 'package:cwatch/services/ssh/builtin/builtin_ssh_key_service.dart';

class ServersModule extends ShellModuleView {
  ServersModule({
    required this.hostsFuture,
    required this.settingsController,
    required this.keyService,
    required this.commandLog,
  });

  final Future<List<SshHost>> hostsFuture;
  final AppSettingsController settingsController;
  final BuiltInSshKeyService keyService;
  final RemoteCommandLogController commandLog;

  @override
  String get id => 'servers';

  @override
  String get label => 'Servers';

  @override
  NerdIcon get icon => NerdIcon.servers;

  @override
  Widget build(BuildContext context, Widget leading) {
    return ServersList(
      hostsFuture: hostsFuture,
      settingsController: settingsController,
      keyService: keyService,
      commandLog: commandLog,
      leading: leading,
    );
  }
}
