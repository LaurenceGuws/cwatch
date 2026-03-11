import 'dart:async';
import 'package:flutter/material.dart';

import 'package:cwatch/model/models/app_settings.dart';
import 'package:cwatch/model/services_infra/settings/app_settings_controller.dart';
import 'package:cwatch/model/shared/theme/theme_runtime_policy.dart';
import 'package:cwatch/model/shared/gestures/gesture_activators.dart';
import 'package:cwatch/model/shared/gestures/gesture_service.dart';
import 'package:cwatch/model/shared/shortcuts/input_mode_resolver.dart';
import 'package:cwatch/model/shared/shortcuts/shortcut_actions.dart';
import 'package:cwatch/model/shared/shortcuts/shortcut_service.dart';
import 'tab_navigation_registry.dart';

class HomeShellInputController {
  HomeShellInputController({
    required this.settingsController,
    required this.platform,
    required this.openCommandPalette,
    required this.handleGlobalPinchZoom,
    required this.focusNextDestination,
    required this.focusPreviousDestination,
    required this.getSelectedDestination,
  });

  final AppSettingsController settingsController;
  final TargetPlatform platform;
  final VoidCallback openCommandPalette;
  final Future<void> Function(double) handleGlobalPinchZoom;
  final VoidCallback focusNextDestination;
  final VoidCallback focusPreviousDestination;
  final String Function() getSelectedDestination;

  bool gesturesEnabled = true;
  GestureSubscription? _globalGestureSub;
  ShortcutSubscription? _globalShortcutSub;

  void init() {
    _configureInputMode(settingsController.settings);
    settingsController.addListener(_onSettingsChanged);
  }

  void dispose() {
    settingsController.removeListener(_onSettingsChanged);
    _globalShortcutSub?.dispose();
    _globalGestureSub?.dispose();
  }

  void _onSettingsChanged() {
    ShortcutService.instance.updateSettings(settingsController.settings);
    _configureInputMode(settingsController.settings);
  }

  void _configureInputMode(AppSettings settings) {
    final config = resolveInputMode(settings.inputModePreference, platform);
    gesturesEnabled = config.enableGestures;

    if (!config.enableShortcuts) {
      _globalShortcutSub?.dispose();
      _globalShortcutSub = null;
    } else {
      _globalShortcutSub ??= ShortcutService.instance.registerScope(
        id: 'global',
        priority: -10,
        handlers: {
          ShortcutActions.globalZoomIn: () => changeAppZoom(0.05),
          ShortcutActions.globalZoomOut: () => changeAppZoom(-0.05),
          ShortcutActions.tabsNext: () => TabNavigationRegistry.instance
              .forModule(getSelectedDestination())
              ?.next(),
          ShortcutActions.tabsPrevious: () => TabNavigationRegistry.instance
              .forModule(getSelectedDestination())
              ?.previous(),
          ShortcutActions.viewsFocusUp: focusPreviousDestination,
          ShortcutActions.viewsFocusDown: focusNextDestination,
          ShortcutActions.globalCommandPalette: openCommandPalette,
        },
        focusNode: null,
      );
    }

    if (!config.enableGestures) {
      _globalGestureSub?.dispose();
      _globalGestureSub = null;
    } else {
      _globalGestureSub ??= GestureService.instance.registerScope(
        id: 'global_gestures',
        priority: -10,
        handlers: {
          Gestures.commandPaletteTripleTap: (_) => openCommandPalette(),
          Gestures.commandPaletteTripleSwipeDown: (_) => openCommandPalette(),
          Gestures.tabsNextSwipe: (_) => TabNavigationRegistry.instance
              .forModule(getSelectedDestination())
              ?.next(),
          Gestures.tabsPreviousSwipe: (_) => TabNavigationRegistry.instance
              .forModule(getSelectedDestination())
              ?.previous(),
          Gestures.viewsFocusUpSwipe: (_) => focusPreviousDestination(),
          Gestures.viewsFocusDownSwipe: (_) => focusNextDestination(),
          Gestures.globalPinchZoom: (invocation) {
            final next = invocation.payloadAs<double>();
            if (next != null) {
              unawaited(handleGlobalPinchZoom(next));
            }
          },
        },
        focusNode: null,
      );
    }
  }

  Future<void> changeAppZoom(double delta) async {
    await settingsController.update((current) {
      final policy = ThemeRuntimePolicy.fromSettings(current);
      final next = policy.clampZoom(current.zoomFactor + delta);
      return current.copyWith(zoomFactor: next);
    });
  }
}
