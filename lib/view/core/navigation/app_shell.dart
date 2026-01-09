import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:tray_manager/tray_manager.dart';

import 'package:cwatch/model/services_infra/settings/app_settings_controller.dart';
import 'package:cwatch/model/shared/gestures/gesture_activators.dart';
import 'package:cwatch/model/shared/gestures/gesture_service.dart';
import 'package:cwatch/view/shared/widgets/command_palette.dart';
import 'home_shell_command_palette.dart';
import 'home_shell_sidebar_menu.dart';
import 'home_shell_view.dart';
import 'package:cwatch/model/services_infra/logging/app_logger.dart';
import 'tab_navigation_registry.dart';
import 'home_shell_controller.dart';
import 'home_shell_state.dart';
import 'widgets/sidebar_menu_button.dart';
import 'widgets/window_controls.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({required this.settingsController, super.key});

  final AppSettingsController settingsController;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell>
    with WindowListener, TrayListener {
  late final HomeShellController _controller;
  double? _scaleStartZoom;

  bool get _supportsCustomChrome =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux);

  @override
  void initState() {
    super.initState();
    _controller = HomeShellController(
      settingsController: widget.settingsController,
      platform: defaultTargetPlatform,
      supportsCustomChrome: _supportsCustomChrome,
    );
    _controller.init(
      context,
      openCommandPalette: _openCommandPalette,
      handleGlobalPinchZoom: _handleGlobalPinchZoom,
    );

    _syncWindowState();
    if (_supportsCustomChrome) {
      trayManager.addListener(this);
    }
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    if (_supportsCustomChrome) {
      trayManager.removeListener(this);
    }
    _controller.dispose();
    super.dispose();
  }

  void _handleDestinationSelected(String destination) {
    _controller.handleDestinationSelected(destination);
  }

  void _focusNextDestination() => _controller.focusNextDestination();

  void _focusPreviousDestination() => _controller.focusPreviousDestination();

  void _focusNextTab() {
    final navigator = TabNavigationRegistry.instance.forModule(
      _controller.state.selectedDestination,
    );
    final handled = navigator?.next() ?? false;
    if (handled) return;
  }

  void _focusPreviousTab() {
    final navigator = TabNavigationRegistry.instance.forModule(
      _controller.state.selectedDestination,
    );
    final handled = navigator?.previous() ?? false;
    if (handled) return;
  }

  void _setSidebarCollapsed(bool collapsed) {
    _controller.persistSidebarCollapsed(collapsed);
  }

  void _toggleSidebar() =>
      _setSidebarCollapsed(!_controller.state.sidebarCollapsed);

  Future<void> _openCommandPalette() async {
    if (_controller.state.paletteOpen) {
      Navigator.of(context, rootNavigator: true).maybePop();
      return;
    }

    _controller.state.paletteOpen = true;

    final entries = HomeShellCommandPalette.buildGlobalEntries(
      context: context,
      settingsController: widget.settingsController,
      moduleId: _controller.state.selectedDestination,
      sidebarCollapsed: _controller.state.sidebarCollapsed,
      focusNextTab: _focusNextTab,
      focusPreviousTab: _focusPreviousTab,
      focusNextDestination: _focusNextDestination,
      focusPreviousDestination: _focusPreviousDestination,
      toggleSidebar: _toggleSidebar,
      showSidebar: () => _setSidebarCollapsed(false),
      hideSidebar: () => _setSidebarCollapsed(true),
    );

    final moduleEntries = await HomeShellCommandPalette.loadModuleEntries(
      moduleId: _controller.state.selectedDestination,
    );
    entries.addAll(moduleEntries);

    if (!mounted || entries.isEmpty) {
      _controller.state.paletteOpen = false;
      return;
    }

    try {
      await showCommandPalette(context, entries: entries);
    } finally {
      _controller.state.paletteOpen = false;
    }
  }

  void _ensurePageCached(String destination, BuildContext context) {
    _controller.state.pageCache.ensurePageCached(
      destination: destination,
      buildPage: () => _buildPageForDestination(destination, context),
    );
  }

  Widget _buildSidebarToggleButton(BuildContext context) {
    return SidebarMenuButton(
      collapsed: _controller.state.sidebarCollapsed,
      onShowOptions: (position) => _showSidebarOptions(context, position),
    );
  }

  Widget _buildPageForDestination(String destination, BuildContext context) {
    final toggleButton = _buildSidebarToggleButton(context);
    final module = _controller.moduleRegistry.modules.isEmpty
        ? null
        : _controller.moduleRegistry.modules.firstWhere(
            (m) => m.id == destination,
            orElse: () => _controller.moduleRegistry.modules.first,
          );
    return module?.build(context, toggleButton) ?? const SizedBox.shrink();
  }

  Future<void> _showSidebarOptions(
    BuildContext context,
    Offset position,
  ) async {
    final choice = await HomeShellSidebarMenu.show(
      context: context,
      position: position,
      sidebarCollapsed: _controller.state.sidebarCollapsed,
      sidebarPlacement: _controller.state.sidebarPlacement,
    );
    if (choice != null) {
      _handleSidebarOption(choice);
    }
  }

  void _handleSidebarOption(SidebarOption option) {
    switch (option) {
      case SidebarOption.hide:
        _controller.persistSidebarCollapsed(true);
        break;
      case SidebarOption.pinLeft:
        _controller.persistSidebarPlacement(SidebarPlacement.left);
        break;
      case SidebarOption.pinRight:
        _controller.persistSidebarPlacement(SidebarPlacement.right);
        break;
      case SidebarOption.pinBottom:
        _controller.persistSidebarPlacement(SidebarPlacement.bottom);
        break;
      case SidebarOption.dynamicPlacement:
        _controller.persistSidebarPlacement(SidebarPlacement.dynamic);
        break;
    }
  }

  void _syncWindowState() {
    if (!_supportsCustomChrome) {
      return;
    }
    windowManager.addListener(this);
    unawaited(() async {
      final maximized = await windowManager.isMaximized();
      if (mounted) {
        _controller.window.setWindowMaximized(maximized);
      }
    }());
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([widget.settingsController, _controller]),
      builder: (context, _) {
        final bool useCustomChrome =
            _supportsCustomChrome &&
            !widget.settingsController.settings.windowUseSystemDecorations;
        final Widget? windowControls = useCustomChrome
            ? WindowControls(
                isMaximized: _controller.state.isWindowMaximized,
                onDrag: _startWindowDrag,
                onToggleMaximize: _toggleWindowMaximize,
                onMinimize: _minimizeWindow,
                onClose: _closeWindow,
              )
            : null;

        return HomeShellView(
          settingsController: widget.settingsController,
          controller: _controller,
          supportsCustomChrome: _supportsCustomChrome,
          ensurePageCached: (context, destination) =>
              _ensurePageCached(destination, context),
          onShowSidebarOptions: (position) =>
              _showSidebarOptions(context, position),
          onDestinationSelected: _handleDestinationSelected,
          windowControls: windowControls,
          onScaleStart: _handleScaleStart,
          onScaleUpdate: _handleScaleUpdate,
          onScaleEnd: _handleScaleEnd,
        );
      },
    );
  }

  void _handleScaleStart(ScaleStartDetails details) {
    if (details.pointerCount < 2) return;
    _scaleStartZoom = widget.settingsController.settings.zoomFactor;
    AppLogger().debug(
      'Pinch zoom start at ${_scaleStartZoom?.toStringAsFixed(2) ?? 'unknown'}',
      tag: 'Gestures',
    );
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    final start = _scaleStartZoom;
    if (start == null || details.pointerCount < 2) return;
    final next = (start * details.scale).clamp(0.8, 1.5).toDouble();
    GestureService.instance.handle(Gestures.globalPinchZoom, payload: next);
  }

  void _handleScaleEnd(ScaleEndDetails details) {
    _scaleStartZoom = null;
  }

  Future<void> _handleGlobalPinchZoom(double targetZoom) async {
    final current = widget.settingsController.settings.zoomFactor;
    if ((current - targetZoom).abs() < 0.005) {
      return;
    }
    AppLogger().debug(
      'Pinch zoom updated app zoom from ${current.toStringAsFixed(2)} '
      'to ${targetZoom.toStringAsFixed(2)}',
      tag: 'Gestures',
    );
    await widget.settingsController.update(
      (settings) => settings.copyWith(zoomFactor: targetZoom),
    );
  }

  Future<void> _startWindowDrag() async {
    if (!_supportsCustomChrome) return;
    await windowManager.startDragging();
  }

  Future<void> _toggleWindowMaximize() async {
    if (!_supportsCustomChrome) return;
    final isMaximized = await windowManager.isMaximized();
    if (isMaximized) {
      await windowManager.unmaximize();
      _controller.window.setWindowMaximized(false);
    } else {
      await windowManager.maximize();
      _controller.window.setWindowMaximized(true);
    }
  }

  Future<void> _minimizeWindow() async {
    if (!_supportsCustomChrome) return;
    await windowManager.minimize();
  }

  Future<void> _closeWindow() async {
    if (!_supportsCustomChrome) return;
    if (widget.settingsController.settings.closeToTray) {
      await _hideToTray();
      return;
    }
    await windowManager.close();
  }

  Future<void> _hideToTray() async {
    await _controller.services.trayService.ensureInitialized();
    await windowManager.hide();
    await windowManager.setSkipTaskbar(true);
  }

  Future<void> _showFromTray() async {
    await windowManager.setSkipTaskbar(false);
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> _quitFromTray() async {
    await _controller.services.trayService.destroy();
    await windowManager.destroy();
  }

  @override
  void onWindowMaximize() {
    _controller.window.setWindowMaximized(true);
  }

  @override
  void onWindowUnmaximize() {
    _controller.window.setWindowMaximized(false);
  }

  @override
  void onWindowClose() {
    if (!_supportsCustomChrome) {
      return;
    }
    if (!widget.settingsController.settings.closeToTray) {
      unawaited(windowManager.destroy());
      return;
    }
    unawaited(_hideToTray());
  }

  @override
  void onTrayIconMouseDown() {
    unawaited(_showFromTray());
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show':
        unawaited(_showFromTray());
        break;
      case 'quit':
        unawaited(_quitFromTray());
        break;
      case 'icon-32':
      case 'icon-64':
      case 'icon-128':
      case 'icon-256':
      case 'icon-512':
      case 'icon-768':
      case 'icon-1024':
        unawaited(
          _controller.services.trayService.setIconChoiceByKey(
            menuItem.key ?? '',
          ),
        );
        break;
    }
  }
}
