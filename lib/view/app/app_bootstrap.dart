import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cwatch/model/services_infra/logging/app_logger.dart';
import 'package:cwatch/model/services_infra/settings/app_settings_controller.dart';
import 'package:cwatch/model/services_infra/ssh/terminal_session.dart';
import 'package:cwatch/model/services_infra/window/window_chrome_service.dart';
import 'package:cwatch/view/core/navigation/app_shell.dart';
import 'package:cwatch/model/shared/theme/theme_config_loader.dart';
import 'package:cwatch/model/shared/theme/theme_factory.dart';
import 'package:cwatch/model/shared/theme/theme_runtime_policy.dart';
import 'package:cwatch/view/shared/views/shared/tabs/terminal/terminal_theme_presets.dart';

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
          theme: ThemeFactory.build(
            settings: settings,
            brightness: Brightness.light,
          ),
          darkTheme: ThemeFactory.build(
            settings: settings,
            brightness: Brightness.dark,
          ),
          builder: (context, child) {
            final mediaQuery = MediaQuery.of(context);
            final themePolicy = ThemeRuntimePolicy.fromSettings(settings);
            return MediaQuery(
              data: mediaQuery.copyWith(
                textScaler: themePolicy.textScalerFor(settings),
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: HomeShell(settingsController: widget.settingsController),
        );
      },
    );
  }
}
