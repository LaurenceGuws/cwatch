import 'package:cwatch/modules/wsl/ui/wsl_tab_builder.dart';
import 'package:cwatch/services/settings/app_settings_controller.dart';

class WslTabBuilderBinding {
  const WslTabBuilderBinding();

  WslTabBuilder create({
    required AppSettingsController settingsController,
  }) {
    return WslTabBuilder(
      settingsController: settingsController,
    );
  }
}
