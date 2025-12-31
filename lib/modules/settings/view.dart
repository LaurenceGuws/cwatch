import 'package:flutter/widgets.dart';

import '../../core/navigation/shell_module.dart';
import 'package:cwatch/models/ssh_host.dart';
import 'package:cwatch/services/settings/app_settings_controller.dart';
import 'package:cwatch/services/ssh/ssh_shell_factory.dart';
import '../../shared/theme/nerd_fonts.dart';
import 'ui/settings/settings_view.dart';
import 'package:cwatch/services/ssh/builtin/builtin_ssh_key_service.dart';

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
