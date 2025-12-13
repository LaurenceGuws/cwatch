import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';

import '../../models/app_settings.dart';

class WindowChromeService {
  WindowChromeService();

  bool get _isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.windows);

  bool _initialized = false;

  Future<void> ensureInitialized(AppSettings settings) async {
    if (_initialized || !_isDesktop) return;
    await windowManager.ensureInitialized();
    final useSystem = settings.windowUseSystemDecorations;
    final options = WindowOptions(
      titleBarStyle: useSystem ? TitleBarStyle.normal : TitleBarStyle.hidden,
      windowButtonVisibility: useSystem,
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      await windowManager.focus();
      _initialized = true;
    });
  }

  Future<void> apply(AppSettings settings) async {
    if (!_isDesktop || !_initialized) return;
    final useSystem = settings.windowUseSystemDecorations;
    // Best-effort per platform.
    if (Platform.isMacOS || Platform.isWindows) {
      await windowManager.setTitleBarStyle(
        useSystem ? TitleBarStyle.normal : TitleBarStyle.hidden,
        windowButtonVisibility: useSystem,
      );
    } else if (Platform.isLinux) {
      // Frameless can still show a thin border depending on WM; this is the
      // closest available toggle.
      if (useSystem) {
        await windowManager.setTitleBarStyle(TitleBarStyle.normal);
      } else {
        await windowManager.setAsFrameless();
      }
    }
  }
}
