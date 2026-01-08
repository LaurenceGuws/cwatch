import 'package:flutter/widgets.dart';

import 'package:cwatch/services/settings/app_settings_controller.dart';
import '../../core/navigation/shell_module.dart';
import '../../shared/theme/nerd_fonts.dart';
import 'services/wsl_service.dart';
import 'ui/wsl_view.dart';

class WslModule extends ShellModuleView {
  const WslModule({required this.settingsController});

  final AppSettingsController settingsController;

  @override
  String get id => 'wsl';

  @override
  String get label => 'WSL';

  @override
  NerdIcon get icon => NerdIcon.penguin;

  @override
  Widget build(BuildContext context, Widget leading) {
    return WslView(
      moduleId: id,
      leading: leading,
      settingsController: settingsController,
      service: createWslService(),
    );
  }
}
