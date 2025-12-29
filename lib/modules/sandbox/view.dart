import 'package:flutter/widgets.dart';

import '../../core/navigation/shell_module.dart';
import '../../shared/theme/nerd_fonts.dart';
import 'ui/sandbox_view.dart';
import '../../services/settings/app_settings_controller.dart';

class SandboxModule extends ShellModuleView {
  const SandboxModule({required this.settingsController});

  final AppSettingsController settingsController;

  @override
  String get id => 'sandbox';

  @override
  String get label => 'Sandbox';

  @override
  NerdIcon get icon => NerdIcon.cloudUpload;

  @override
  bool get isPrimary => false;

  @override
  Widget build(BuildContext context, Widget leading) {
    return SandboxView(
      leading: leading,
      settingsController: settingsController,
    );
  }
}
