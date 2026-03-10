import 'package:cwatch/model/models/app_settings.dart';
import 'package:cwatch/model/services_infra/ssh/builtin/builtin_ssh_key_service.dart';
import 'package:cwatch/model/services_infra/ssh/builtin/builtin_ssh_key_store.dart';
import 'package:cwatch/model/services_infra/ssh/builtin/builtin_ssh_vault.dart';
import 'package:cwatch/model/services_infra/ssh/ssh_auth_coordinator.dart';
import 'package:cwatch/model/services_infra/ssh/ssh_shell_factory.dart';
import 'package:cwatch/model/services_infra/window/tray_service.dart';
import 'package:cwatch/model/services_infra/window/window_chrome_service.dart';
import 'package:cwatch/view/core/navigation/gesture_detector_factory.dart';

class HomeShellServices {
  late final BuiltInSshKeyStore keyStore;
  late final BuiltInSshVault vault;
  late final BuiltInSshKeyService keyService;
  late final SshAuthCoordinator authCoordinator;
  late final SshShellFactory shellFactory;
  late final WindowChromeService windowChrome;
  late final TrayService trayService;
  late final GestureDetectorFactory gestureDetectorFactory;

  void handleSettingsChanged(AppSettings settings) {
    shellFactory.handleSettingsChanged(settings);
  }

  void dispose() {
    gestureDetectorFactory.dispose();
  }
}
