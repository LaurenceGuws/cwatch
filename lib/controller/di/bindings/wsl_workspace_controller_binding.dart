import 'package:cwatch/controller/core/workspace/workspace_tab.dart';
import 'package:cwatch/controller/controllers/wsl_workspace_controller.dart';
import 'package:cwatch/model/services_infra/settings/app_settings_controller.dart';

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
