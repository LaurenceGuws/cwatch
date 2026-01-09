import 'package:cwatch/view/features/wsl/wsl_tab_builder.dart';
import 'package:cwatch/model/services_infra/settings/app_settings_controller.dart';

class WslTabBuilderBinding {
  const WslTabBuilderBinding();

  WslTabBuilder create({required AppSettingsController settingsController}) {
    return WslTabBuilder(settingsController: settingsController);
  }
}
