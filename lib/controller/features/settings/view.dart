import 'package:flutter/widgets.dart';

import 'package:cwatch/view/core/navigation/shell_module.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/services_infra/settings/app_settings_controller.dart';
import 'package:cwatch/model/services_infra/ssh/ssh_shell_factory.dart';
import 'package:cwatch/model/shared/theme/nerd_fonts.dart';
import 'package:cwatch/view/features/settings/settings/settings_view.dart';
import 'package:cwatch/model/services_infra/ssh/builtin/builtin_ssh_key_service.dart';

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
