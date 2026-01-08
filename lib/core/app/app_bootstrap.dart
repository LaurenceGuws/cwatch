import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cwatch/services/logging/app_logger.dart';
import '../../services/settings/app_settings_controller.dart';
import '../../services/ssh/terminal_session.dart';
import '../../services/window/window_chrome_service.dart';
import '../navigation/app_shell.dart';
import '../../shared/theme/theme_config_loader.dart';
import '../../shared/theme/theme_factory.dart';
import '../../shared/views/shared/tabs/terminal/terminal_theme_presets.dart';

Future<void> runAppBootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalPtySession.cleanupStaleSessions();
  final settingsController = AppSettingsController();
  await settingsController.load();
  AppLogger.configure(
    minLevel: settingsController.settings.debugMode
        ? LogLevel.trace
        : LogLevel.warning,
  );
  await ensureThemeExamples();
  await loadAssetTerminalThemes();
  await reloadUserTerminalThemes();
  await applyThemeConfigOverrides(settingsController);
  await WindowChromeService().ensureInitialized(settingsController.settings);
  runApp(CwatchApp(settingsController: settingsController));
}

class CwatchApp extends StatefulWidget {
  const CwatchApp({required this.settingsController, super.key});

  final AppSettingsController settingsController;

  @override
  State<CwatchApp> createState() => _CwatchAppState();
}

class _CwatchAppState extends State<CwatchApp> {
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.settingsController,
      builder: (context, _) {
        final settings = widget.settingsController.settings;
        return MaterialApp(
          title: 'CWatch',
          themeMode: settings.themeMode,
          theme: ThemeFactory.build(settings: settings, brightness: Brightness.light),
          darkTheme: ThemeFactory.build(settings: settings, brightness: Brightness.dark),
          builder: (context, child) {
            final mediaQuery = MediaQuery.of(context);
            final zoom = settings.zoomFactor.clamp(0.8, 1.5).toDouble();
            return MediaQuery(
              data: mediaQuery.copyWith(textScaler: TextScaler.linear(zoom)),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: HomeShell(settingsController: widget.settingsController),
        );
      },
    );
  }
}
