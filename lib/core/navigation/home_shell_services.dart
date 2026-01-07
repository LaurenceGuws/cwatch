import 'package:flutter/material.dart';

import '../../models/app_settings.dart';
import '../../services/settings/app_settings_controller.dart';
import '../../services/ssh/builtin/builtin_ssh_key_service.dart';
import '../../services/ssh/builtin/builtin_ssh_key_store.dart';
import '../../services/ssh/builtin/builtin_ssh_vault.dart';
import '../../services/ssh/ssh_auth_coordinator.dart';
import '../../services/ssh/ssh_auth_prompter.dart';
import '../../services/ssh/ssh_shell_factory.dart';
import '../../services/window/tray_service.dart';
import '../../services/window/window_chrome_service.dart';
import 'gesture_detector_factory.dart';

class HomeShellServices {
  late final BuiltInSshKeyStore keyStore;
  late final BuiltInSshVault vault;
  late final BuiltInSshKeyService keyService;
  late final SshAuthCoordinator authCoordinator;
  late final SshShellFactory shellFactory;
  late final WindowChromeService windowChrome;
  late final TrayService trayService;
  late final GestureDetectorFactory gestureDetectorFactory;

  void init({
    required BuildContext context,
    required AppSettingsController settingsController,
  }) {
    keyStore = BuiltInSshKeyStore();
    vault = BuiltInSshVault(keyStore: keyStore);
    keyService = BuiltInSshKeyService(keyStore: keyStore, vault: vault);
    authCoordinator = SshAuthPrompter.forContext(
      context: context,
      keyService: keyService,
    );
    windowChrome = WindowChromeService();
    trayService = TrayService();
    shellFactory = SshShellFactory(
      settingsController: settingsController,
      keyService: keyService,
      authCoordinator: authCoordinator,
    );
    gestureDetectorFactory = GestureDetectorFactory();
  }

  void handleSettingsChanged(AppSettings settings) {
    shellFactory.handleSettingsChanged(settings);
  }

  void dispose() {
    gestureDetectorFactory.dispose();
  }
}
