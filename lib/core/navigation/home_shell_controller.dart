import 'dart:async';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../models/app_settings.dart';
import '../../services/logging/app_logger.dart';
import '../../services/settings/app_settings_controller.dart';
import '../../shared/gestures/gesture_activators.dart';
import '../../shared/gestures/gesture_service.dart';
import '../../shared/shortcuts/input_mode_resolver.dart';
import '../../shared/shortcuts/shortcut_actions.dart';
import '../../shared/shortcuts/shortcut_service.dart';
import 'home_shell_modules.dart';
import 'home_shell_services.dart';
import 'home_shell_state.dart';
import 'module_registry.dart';
import 'tab_navigation_registry.dart';

class HomeShellController extends ChangeNotifier {
  HomeShellController({
    required this.settingsController,
    required this.platform,
    required this.supportsCustomChrome,
  });

  final AppSettingsController settingsController;
  final TargetPlatform platform;
  final bool supportsCustomChrome;

  final HomeShellState state = HomeShellState();
  final HomeShellServices services = HomeShellServices();

  late final ModuleRegistry moduleRegistry;

  bool gesturesEnabled = true;
  GestureSubscription? _globalGestureSub;
  ShortcutSubscription? _globalShortcutSub;

  VoidCallback? _openCommandPalette;
  Future<void> Function(double)? _handleGlobalPinchZoom;

  bool _initialized = false;

  void init(
    BuildContext context, {
    required VoidCallback openCommandPalette,
    required Future<void> Function(double) handleGlobalPinchZoom,
  }) {
    if (_initialized) return;
    _initialized = true;
    _openCommandPalette = openCommandPalette;
    _handleGlobalPinchZoom = handleGlobalPinchZoom;

    services.init(context: context, settingsController: settingsController);
    state.refreshHosts(settingsController.settings);

    moduleRegistry = ModuleRegistry(
      buildHomeShellModules(
        hostsFuture: state.hostsFuture,
        settingsController: settingsController,
        keyService: services.keyService,
        shellFactory: services.shellFactory,
        isWindows: platform == TargetPlatform.windows,
      ),
    );

    moduleRegistry.addListener(_handleModulesChanged);
    state.hostsSettingsSignature = state.hostSettingsSignature(
      settingsController.settings,
    );

    _applyShellSettings(settingsController.settings);
    state.shellStateRestored = settingsController.isLoaded;

    settingsController.addListener(_handleSettingsChanged);

    ShortcutService.instance.updateSettings(settingsController.settings);
    AppLogger.configureRemoteCommandLogging(
      enabled: settingsController.settings.debugMode,
    );

    _configureInputMode(settingsController.settings);

    if (supportsCustomChrome) {
      unawaited(_configureCloseToTray(settingsController.settings));
    }
  }

  @override
  void dispose() {
    if (_initialized) {
      moduleRegistry.removeListener(_handleModulesChanged);
      settingsController.removeListener(_handleSettingsChanged);
    }
    _globalShortcutSub?.dispose();
    _globalGestureSub?.dispose();
    services.dispose();
    super.dispose();
  }

  void setWindowMaximized(bool value) {
    if (state.isWindowMaximized == value) return;
    state.isWindowMaximized = value;
    notifyListeners();
  }

  void _handleModulesChanged() {
    final modules = moduleRegistry.modules;
    if (modules.isEmpty) {
      if (state.selectedDestination.isNotEmpty) {
        state.selectedDestination = '';
        notifyListeners();
      }
      return;
    }

    final exists = modules.any(
      (module) => module.id == state.selectedDestination,
    );
    if (!exists) {
      state.selectedDestination = modules.first.id;
      notifyListeners();
    }
  }

  void _handleSettingsChanged() {
    if (!settingsController.isLoaded) {
      return;
    }

    if (!state.shellStateRestored) {
      final previousDestination = state.selectedDestination;
      _applyShellSettings(settingsController.settings);
      if (state.selectedDestination != previousDestination) {
        state.pageCache.evictAllExcept(state.selectedDestination);
      }
      state.shellStateRestored = true;
      notifyListeners();
    }

    ShortcutService.instance.updateSettings(settingsController.settings);
    services.handleSettingsChanged(settingsController.settings);
    _configureInputMode(settingsController.settings);

    if (moduleRegistry.modules.isEmpty) {
      return;
    }

    final nextSignature = state.hostSettingsSignature(
      settingsController.settings,
    );
    if (nextSignature != state.hostsSettingsSignature) {
      state.hostsSettingsSignature = nextSignature;
      state.refreshHosts(settingsController.settings);
      notifyListeners();
    }

    unawaited(services.windowChrome.apply(settingsController.settings));
    unawaited(_configureCloseToTray(settingsController.settings));
  }

  void _applyShellSettings(AppSettings settings) {
    AppLogger.configureRemoteCommandLogging(enabled: settings.debugMode);
    state.selectedDestination =
        _destinationFromName(settings.shellDestination) ??
        state.selectedDestination;
    state.sidebarCollapsed = settings.shellSidebarCollapsed;
    state.sidebarPlacement = state.placementFromString(
      settings.shellSidebarPlacement,
    );
    unawaited(services.windowChrome.apply(settings));
    unawaited(_configureCloseToTray(settings));
    _configureInputMode(settings);
  }

  String? _destinationFromName(String? value) =>
      moduleRegistry.modules.any((module) => module.id == value)
      ? value
      : (moduleRegistry.modules.isNotEmpty
            ? moduleRegistry.modules.first.id
            : null);

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

  void _configureInputMode(AppSettings settings) {
    final config = resolveInputMode(settings.inputModePreference, platform);
    if (gesturesEnabled != config.enableGestures) {
      gesturesEnabled = config.enableGestures;
      notifyListeners();
    } else {
      gesturesEnabled = config.enableGestures;
    }

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
              .forModule(state.selectedDestination)
              ?.next(),
          ShortcutActions.tabsPrevious: () => TabNavigationRegistry.instance
              .forModule(state.selectedDestination)
              ?.previous(),
          ShortcutActions.viewsFocusUp: focusPreviousDestination,
          ShortcutActions.viewsFocusDown: focusNextDestination,
          ShortcutActions.globalCommandPalette: () =>
              _openCommandPalette?.call(),
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
          Gestures.commandPaletteTripleTap: (_) => _openCommandPalette?.call(),
          Gestures.commandPaletteTripleSwipeDown: (_) =>
              _openCommandPalette?.call(),
          Gestures.tabsNextSwipe: (_) => TabNavigationRegistry.instance
              .forModule(state.selectedDestination)
              ?.next(),
          Gestures.tabsPreviousSwipe: (_) => TabNavigationRegistry.instance
              .forModule(state.selectedDestination)
              ?.previous(),
          Gestures.viewsFocusUpSwipe: (_) => focusPreviousDestination(),
          Gestures.viewsFocusDownSwipe: (_) => focusNextDestination(),
          Gestures.globalPinchZoom: (invocation) {
            final next = invocation.payloadAs<double>();
            if (next != null) {
              unawaited(_handleGlobalPinchZoom?.call(next));
            }
          },
        },
        focusNode: null,
      );
    }
  }

  Future<void> changeAppZoom(double delta) async {
    await settingsController.update((current) {
      final next = (current.zoomFactor + delta).clamp(0.8, 1.5).toDouble();
      return current.copyWith(zoomFactor: next);
    });
  }

  void focusNextDestination() {
    final modules = moduleRegistry.modules;
    if (modules.isEmpty) return;
    final currentIndex = modules.indexWhere(
      (m) => m.id == state.selectedDestination,
    );
    final nextIndex = (currentIndex + 1) % modules.length;
    handleDestinationSelected(modules[nextIndex].id);
  }

  void focusPreviousDestination() {
    final modules = moduleRegistry.modules;
    if (modules.isEmpty) return;
    final currentIndex = modules.indexWhere(
      (m) => m.id == state.selectedDestination,
    );
    final prevIndex = (currentIndex - 1 + modules.length) % modules.length;
    handleDestinationSelected(modules[prevIndex].id);
  }

  void handleDestinationSelected(String destination) {
    if (state.selectedDestination == destination) {
      return;
    }
    state.selectedDestination = destination;
    notifyListeners();
    _persistShellState(destination: destination);
  }

  void persistSidebarCollapsed(bool collapsed) {
    if (state.sidebarCollapsed == collapsed) return;
    state.sidebarCollapsed = collapsed;
    notifyListeners();
    _persistShellState(collapsed: collapsed);
  }

  void persistSidebarPlacement(SidebarPlacement placement) {
    state.sidebarCollapsed = false;
    state.sidebarPlacement = placement;
    notifyListeners();
    _persistShellState(collapsed: false, placement: placement);
  }

  void _persistShellState({
    String? destination,
    bool? collapsed,
    SidebarPlacement? placement,
  }) {
    final targetDestination = destination ?? state.selectedDestination;
    final settings = settingsController.settings;
    final targetCollapsed = collapsed ?? state.sidebarCollapsed;
    final targetPlacement = placement ?? state.sidebarPlacement;

    if (settings.shellDestination == targetDestination &&
        settings.shellSidebarCollapsed == targetCollapsed &&
        settings.shellSidebarPlacement ==
            state.placementToString(targetPlacement)) {
      return;
    }

    unawaited(
      settingsController.update(
        (current) => current.copyWith(
          shellDestination: targetDestination,
          shellSidebarCollapsed: targetCollapsed,
          shellSidebarPlacement: state.placementToString(targetPlacement),
        ),
      ),
    );
  }
}
