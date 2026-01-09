import 'package:flutter/widgets.dart';

import 'package:cwatch/model/services_infra/settings/app_settings_controller.dart';
import 'package:cwatch/view/core/navigation/shell_module.dart';
import 'package:cwatch/model/shared/theme/nerd_fonts.dart';
import 'package:cwatch/model/features/wsl/services/wsl_service.dart';
import 'package:cwatch/view/features/wsl/wsl_view.dart';

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
