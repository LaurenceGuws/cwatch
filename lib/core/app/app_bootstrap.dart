import 'dart:async';

import 'package:flutter/material.dart';

import 'package:cwatch/models/app_settings.dart';
import '../../services/settings/app_settings_controller.dart';
import '../../services/ssh/terminal_session.dart';
import '../../services/window/window_chrome_service.dart';
import '../navigation/app_shell.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/theme/theme_config_loader.dart';
import '../../shared/views/shared/tabs/terminal/terminal_theme_presets.dart';

Future<void> runAppBootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalPtySession.cleanupStaleSessions();
  final settingsController = AppSettingsController();
  await settingsController.load();
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
        final appFontFamily = settings.appFontFamily;
        final baseRadius = BorderRadius.circular(2);
        final spacingBase = settings.uiDensity == AppUiDensity.comfy ? 5.0 : 4.0;
        final seed = _seedForKey(settings.appThemeKey);
        final lightScheme = ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.light,
        );
        final darkScheme = ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
        );
        final lightTokens = AppThemeTokens.light(
          lightScheme,
          fontFamily: appFontFamily,
          surfaceRadius: baseRadius,
          spacingBase: spacingBase,
        );
        final darkTokens = AppThemeTokens.dark(
          darkScheme,
          fontFamily: appFontFamily,
          surfaceRadius: baseRadius,
          spacingBase: spacingBase,
        );
        return MaterialApp(
          title: 'CWatch',
          themeMode: settings.themeMode,
          theme: _buildTheme(
            lightScheme,
            lightTokens,
            appFontFamily,
            baseRadius: baseRadius,
            visualDensity:
                settings.uiDensity == AppUiDensity.comfy
                    ? VisualDensity.standard
                    : VisualDensity.compact,
          ),
          darkTheme: _buildTheme(
            darkScheme,
            darkTokens,
            appFontFamily,
            baseRadius: baseRadius,
            visualDensity:
                settings.uiDensity == AppUiDensity.comfy
                    ? VisualDensity.standard
                    : VisualDensity.compact,
          ),
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

  ThemeData _buildTheme(
    ColorScheme scheme,
    AppThemeTokens tokens,
    String? fontFamily,
    {
      required BorderRadius baseRadius,
      required VisualDensity visualDensity,
    }
  ) {
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      fontFamily: fontFamily,
      visualDensity: visualDensity,
      scaffoldBackgroundColor: scheme.surface,
      cardTheme: CardThemeData(
        elevation: 0.5,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: baseRadius),
        color: scheme.surfaceContainerHigh,
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        centerTitle: false,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 0,
      ),
      listTileTheme: ListTileThemeData(
        dense: true,
        contentPadding: tokens.spacing.inset(horizontal: 2, vertical: 1),
        shape: RoundedRectangleBorder(borderRadius: baseRadius),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.8),
        border: OutlineInputBorder(
          borderRadius: baseRadius,
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: baseRadius,
          borderSide: BorderSide(color: scheme.primary),
        ),
        contentPadding: tokens.spacing.inset(horizontal: 2, vertical: 1.5),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: baseRadius),
      ),
      popupMenuTheme: PopupMenuThemeData(
        shape: RoundedRectangleBorder(borderRadius: baseRadius),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: baseRadius),
          ),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: baseRadius),
          ),
        ),
      ),
      scrollbarTheme: ScrollbarThemeData(
        radius: const Radius.circular(2),
        thickness: WidgetStateProperty.all(4),
        thumbVisibility: WidgetStateProperty.all(true),
        thumbColor: WidgetStateProperty.all(
          scheme.outlineVariant.withValues(alpha: 0.7),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 0,
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: baseRadius),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: baseRadius),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: baseRadius),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: baseRadius),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: baseRadius),
          ),
        ),
      ),
      extensions: [tokens],
    );
  }

  Color _seedForKey(String key) {
    switch (key) {
      case 'teal':
        return Colors.teal;
      case 'amber':
        return Colors.amber;
      case 'indigo':
        return Colors.indigo;
      case 'purple':
        return Colors.deepPurple;
      case 'green':
        return Colors.green;
      case 'blue-grey':
      default:
        return Colors.blueGrey;
    }
  }
}
