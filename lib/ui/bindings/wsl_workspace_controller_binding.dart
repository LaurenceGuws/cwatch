import 'package:cwatch/core/workspace/workspace_tab.dart';
import 'package:cwatch/modules/wsl/ui/wsl_workspace_controller.dart';
import 'package:cwatch/services/settings/app_settings_controller.dart';

class WslWorkspaceControllerBinding {
  const WslWorkspaceControllerBinding();

  WslWorkspaceController create({
    required AppSettingsController settingsController,
    required WorkspaceTab Function() baseTabBuilder,
  }) {
    return WslWorkspaceController(
      settingsController: settingsController,
      baseTabBuilder: baseTabBuilder,
    );
  }
}
