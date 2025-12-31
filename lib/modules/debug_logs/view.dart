import 'package:flutter/widgets.dart';

import '../../core/navigation/shell_module.dart';
import '../../services/settings/app_settings_controller.dart';
import '../../shared/theme/nerd_fonts.dart';
import 'ui/debug_logs_view.dart';

class DebugLogsModule extends ShellModuleView {
  DebugLogsModule({required this.settingsController});

  final AppSettingsController settingsController;

  @override
  String get id => 'debug_logs';

  @override
  String get label => 'Debug Logs';

  @override
  NerdIcon get icon => NerdIcon.alert;

  @override
  bool get isPrimary => false;

  @override
  Widget build(BuildContext context, Widget leading) {
    return DebugLogsView(
      settingsController: settingsController,
      leading: leading,
    );
  }
}
