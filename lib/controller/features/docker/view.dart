import 'package:flutter/widgets.dart';

import 'package:cwatch/view/core/navigation/shell_module.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/services_infra/settings/app_settings_controller.dart';
import 'package:cwatch/model/services_infra/ssh/builtin/builtin_ssh_key_service.dart';
import 'package:cwatch/model/services_infra/ssh/ssh_shell_factory.dart';
import 'package:cwatch/model/shared/theme/nerd_fonts.dart';
import 'package:cwatch/view/features/docker/docker_view.dart';

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
