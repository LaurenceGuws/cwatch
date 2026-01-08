import 'dart:async';
import 'package:window_manager/window_manager.dart';

import '../../models/app_settings.dart';
import '../../services/settings/app_settings_controller.dart';
import 'home_shell_services.dart';
import 'home_shell_state.dart';

class HomeShellWindowController {
  HomeShellWindowController({
    required this.settingsController,
    required this.services,
    required this.state,
    required this.supportsCustomChrome,
    required this.notifyListeners,
  });

  final AppSettingsController settingsController;
  final HomeShellServices services;
  final HomeShellState state;
  final bool supportsCustomChrome;
  final void Function() notifyListeners;

  void init() {
    if (supportsCustomChrome) {
      unawaited(_configureCloseToTray(settingsController.settings));
    }
    settingsController.addListener(_onSettingsChanged);
  }

  void dispose() {
    settingsController.removeListener(_onSettingsChanged);
  }

  void _onSettingsChanged() {
    unawaited(services.windowChrome.apply(settingsController.settings));
    unawaited(_configureCloseToTray(settingsController.settings));
  }

  void setWindowMaximized(bool value) {
    if (state.isWindowMaximized == value) return;
    state.isWindowMaximized = value;
    notifyListeners();
  }

  Future<void> _configureCloseToTray(AppSettings settings) async {
    if (!supportsCustomChrome) {
      return;
    }
    final enable = settings.closeToTray;
    if (state.closeToTrayEnabled == enable) {
      return;
    }
    state.closeToTrayEnabled = enable;
    await windowManager.setPreventClose(enable);
    if (enable) {
      await services.trayService.ensureInitialized();
    } else {
      await windowManager.setSkipTaskbar(false);
      await services.trayService.destroy();
    }
  }
}
