import 'package:flutter/widgets.dart';

import 'package:cwatch/view/core/navigation/shell_module.dart';
import 'package:cwatch/model/services_infra/settings/app_settings_controller.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/services_infra/ssh/ssh_shell_factory.dart';
import 'package:cwatch/view/features/servers/server_workspace_view.dart';
import 'package:cwatch/model/shared/theme/nerd_fonts.dart';
import 'package:cwatch/model/services_infra/ssh/builtin/builtin_ssh_key_service.dart';

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
