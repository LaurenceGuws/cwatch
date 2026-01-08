import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/app_settings.dart';
import '../../services/logging/app_logger.dart';
import '../../services/settings/app_settings_controller.dart';
import 'home_shell_input_controller.dart';
import 'home_shell_modules.dart';
import 'home_shell_services.dart';
import 'home_shell_state.dart';
import 'home_shell_window_controller.dart';
import 'module_registry.dart';

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
  late final HomeShellInputController input;
  late final HomeShellWindowController window;

  bool _initialized = false;

  void init(
    BuildContext context, {
    required VoidCallback openCommandPalette,
    required Future<void> Function(double) handleGlobalPinchZoom,
  }) {
    if (_initialized) return;
    _initialized = true;

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

    input = HomeShellInputController(
      settingsController: settingsController,
      platform: platform,
      openCommandPalette: openCommandPalette,
      handleGlobalPinchZoom: handleGlobalPinchZoom,
      focusNextDestination: focusNextDestination,
      focusPreviousDestination: focusPreviousDestination,
      getSelectedDestination: () => state.selectedDestination,
    );
    input.init();

    window = HomeShellWindowController(
      settingsController: settingsController,
      services: services,
      state: state,
      supportsCustomChrome: supportsCustomChrome,
      notifyListeners: notifyListeners,
    );
    window.init();

    moduleRegistry.addListener(_handleModulesChanged);
    state.hostsSettingsSignature = state.hostSettingsSignature(
      settingsController.settings,
    );

    _applyShellSettings(settingsController.settings);
    state.shellStateRestored = settingsController.isLoaded;

    settingsController.addListener(_handleSettingsChanged);

    AppLogger.configureRemoteCommandLogging(
      enabled: settingsController.settings.debugMode,
    );
  }

  @override
  void dispose() {
    if (_initialized) {
      moduleRegistry.removeListener(_handleModulesChanged);
      settingsController.removeListener(_handleSettingsChanged);
      input.dispose();
      window.dispose();
    }
    services.dispose();
    super.dispose();
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

    services.handleSettingsChanged(settingsController.settings);

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
  }

  String? _destinationFromName(String? value) =>
      moduleRegistry.modules.any((module) => module.id == value)
      ? value
      : (moduleRegistry.modules.isNotEmpty
            ? moduleRegistry.modules.first.id
            : null);

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
