import 'package:flutter/material.dart';

import 'package:cwatch/app/adapters/settings_ui_adapter.dart';
import 'package:cwatch/app/controllers/settings_controller.dart';
import 'package:cwatch/core/navigation/command_palette_registry.dart';
import 'package:cwatch/core/navigation/tab_navigation_registry.dart';
import 'package:cwatch/models/ssh_host.dart';
import 'package:cwatch/services/settings/app_settings_controller.dart';
import 'package:cwatch/services/ssh/builtin/builtin_ssh_key_service.dart';
import 'package:cwatch/services/ssh/ssh_shell_factory.dart';
import 'package:cwatch/shared/theme/nerd_fonts.dart';
import 'package:cwatch/shared/widgets/section_nav_bar.dart';
import 'package:cwatch/ui/bindings/settings_binding.dart';
import 'container_settings_tabs.dart';
import 'editor_settings_tab.dart';
import 'explorer_settings_tab.dart';
import 'general_settings_tab.dart';
import 'servers_settings_tab.dart';
import 'terminal_settings_tab.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({
    required this.controller,
    required this.hostsFuture,
    required this.keyService,
    required this.shellFactory,
    this.leading,
    super.key,
  });

  final AppSettingsController controller;
  final Future<List<SshHost>> hostsFuture;
  final BuiltInSshKeyService keyService;
  final SshShellFactory shellFactory;
  final Widget? leading;

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView>
    with SingleTickerProviderStateMixin {
  final SettingsBinding _binding = const SettingsBinding();
  late final SettingsUiAdapter _uiAdapter;
  late final SettingsController _controller;
  late final TabController _tabController;
  late final VoidCallback _settingsListener;
  late final TabNavigationHandle _tabNavigator;
  late final CommandPaletteHandle _commandPaletteHandle;

  static const _tabs = [
    Tab(text: 'General'),
    Tab(text: 'Explorer'),
    Tab(text: 'Servers'),
    Tab(text: 'Docker'),
    Tab(text: 'Kubernetes'),
    Tab(text: 'Terminal'),
    Tab(text: 'Editor'),
  ];

  static final _tabIcons = [
    Icons.settings_outlined, // General
    Icons.folder_open, // Explorer
    Icons.storage, // Servers
    NerdIcon.docker.data, // Docker
    NerdIcon.kubernetes.data, // Kubernetes
    Icons.terminal, // Terminal
    Icons.code, // Editor
  ];

  @override
  void initState() {
    super.initState();
    _uiAdapter = _binding.createUiAdapter(context: context);
    _controller = _binding.createController(
      settingsController: widget.controller,
      hostsFuture: widget.hostsFuture,
      keyService: widget.keyService,
      uiAdapter: _uiAdapter,
    );
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabNavigator = TabNavigationHandle(
      next: () {
        if (_tabController.length <= 1) return false;
        final next = (_tabController.index + 1) % _tabController.length;
        _tabController.index = next;
        return true;
      },
      previous: () {
        if (_tabController.length <= 1) return false;
        final prev =
            (_tabController.index - 1 + _tabController.length) %
            _tabController.length;
        _tabController.index = prev;
        return true;
      },
    );
    TabNavigationRegistry.instance.register('settings', _tabNavigator);
    _commandPaletteHandle = CommandPaletteHandle(
      loader: () => _buildCommandPaletteEntries(),
    );
    CommandPaletteRegistry.instance.register('settings', _commandPaletteHandle);
    _tabController.addListener(_handleTabChanged);
    _settingsListener = _syncTabFromSettings;
    _controller.addListener(_settingsListener);
    _syncTabFromSettings();
  }

  @override
  void dispose() {
    TabNavigationRegistry.instance.unregister('settings', _tabNavigator);
    CommandPaletteRegistry.instance.unregister(
      'settings',
      _commandPaletteHandle,
    );
    _controller.removeListener(_settingsListener);
    _controller.dispose();
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  List<CommandPaletteEntry> _buildCommandPaletteEntries() {
    final entries = <CommandPaletteEntry>[];
    for (var i = 0; i < _tabs.length; i++) {
      final label = _tabs[i].text ?? 'Tab ${i + 1}';
      entries.add(
        CommandPaletteEntry(
          id: 'settings:tab:$i',
          label: 'Open $label settings',
          category: 'Settings',
          onSelected: () => _tabController.index = i,
          icon: _tabIcons[i],
        ),
      );
    }
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final settings = _controller.settings;
        return Column(
          children: [
            SectionNavBar(
              title: 'Settings',
              tabs: _tabs,
              tabIcons: _tabIcons,
              controller: _tabController,
              showTitle: false,
              leading: widget.leading,
              enableWindowDrag: !settings.windowUseSystemDecorations,
            ),
            Expanded(
              child: _controller.isLoaded
                  ? TabBarView(
                      controller: _tabController,
                      children: [
                        GeneralSettingsTab(
                          settings: settings,
                          settingsController: _controller,
                          selectedTheme: settings.themeMode,
                          debugMode: settings.debugMode,
                          zoomFactor: settings.zoomFactor,
                          onThemeChanged: (mode) => _controller.update(
                            (current) => current.copyWith(themeMode: mode),
                          ),
                          onDebugModeChanged: (value) => _controller.update(
                            (current) => current.copyWith(debugMode: value),
                          ),
                          onZoomChanged: (value) => _controller.update(
                            (current) => current.copyWith(zoomFactor: value),
                          ),
                          appFontFamily: settings.appFontFamily,
                          onAppFontFamilyChanged: (value) => _controller.update(
                            (current) => current.copyWith(
                              appFontFamily: value.trim().isEmpty
                                  ? null
                                  : value.trim(),
                            ),
                          ),
                          appThemeKey: settings.appThemeKey,
                          onAppThemeChanged: (value) => _controller.update(
                            (current) => current.copyWith(appThemeKey: value),
                          ),
                          uiDensity: settings.uiDensity,
                          onUiDensityChanged: (value) => _controller.update(
                            (current) => current.copyWith(uiDensity: value),
                          ),
                          inputModePreference: settings.inputModePreference,
                          onInputModePreferenceChanged: (value) =>
                              _controller.update(
                                (current) => current.copyWith(
                                  inputModePreference: value,
                                ),
                              ),
                        ),
                        ExplorerSettingsTab(
                          settings: settings,
                          settingsController: _controller,
                        ),
                        ServersSettingsTab(
                          key: const ValueKey('servers_settings_tab'),
                          controller: _controller,
                        ),
                        DockerSettingsTab(
                          logsTail: settings.dockerLogsTailClamped,
                          onLogsTailChanged: (value) => _controller.update(
                            (current) =>
                                current.copyWith(dockerLogsTail: value),
                          ),
                        ),
                        KubernetesSettingsTab(
                          settings: settings,
                          settingsController: _controller,
                        ),
                        TerminalSettingsTab(
                          settings: settings,
                          settingsController: _controller,
                          fontFamily: settings.terminalFontFamily,
                          fontSize: settings.terminalFontSize,
                          lineHeight: settings.terminalLineHeight,
                          paddingX: settings.terminalPaddingX,
                          paddingY: settings.terminalPaddingY,
                          darkTheme: settings.terminalThemeDark,
                          lightTheme: settings.terminalThemeLight,
                          onFontFamilyChanged: (value) => _controller.update(
                            (current) => current.copyWith(
                              terminalFontFamily: value.trim().isEmpty
                                  ? null
                                  : value.trim(),
                            ),
                          ),
                          onFontSizeChanged: (value) => _controller.update(
                            (current) =>
                                current.copyWith(terminalFontSize: value),
                          ),
                          onLineHeightChanged: (value) => _controller.update(
                            (current) =>
                                current.copyWith(terminalLineHeight: value),
                          ),
                          onPaddingXChanged: (value) => _controller.update(
                            (current) =>
                                current.copyWith(terminalPaddingX: value),
                          ),
                          onPaddingYChanged: (value) => _controller.update(
                            (current) =>
                                current.copyWith(terminalPaddingY: value),
                          ),
                          onDarkThemeChanged: (value) => _controller.update(
                            (current) =>
                                current.copyWith(terminalThemeDark: value),
                          ),
                          onLightThemeChanged: (value) => _controller.update(
                            (current) =>
                                current.copyWith(terminalThemeLight: value),
                          ),
                        ),
                        EditorSettingsTab(
                          settings: settings,
                          settingsController: _controller,
                          fontFamily: settings.editorFontFamily,
                          fontSize: settings.editorFontSize,
                          lineHeight: settings.editorLineHeight,
                          onFontFamilyChanged: (value) => _controller.update(
                            (current) => current.copyWith(
                              editorFontFamily: value.trim().isEmpty
                                  ? null
                                  : value.trim(),
                            ),
                          ),
                          onFontSizeChanged: (value) => _controller.update(
                            (current) =>
                                current.copyWith(editorFontSize: value),
                          ),
                          onLineHeightChanged: (value) => _controller.update(
                            (current) =>
                                current.copyWith(editorLineHeight: value),
                          ),
                          lightTheme: settings.editorThemeLight,
                          darkTheme: settings.editorThemeDark,
                          onLightThemeChanged: (value) => _controller.update(
                            (current) =>
                                current.copyWith(editorThemeLight: value),
                          ),
                          onDarkThemeChanged: (value) => _controller.update(
                            (current) =>
                                current.copyWith(editorThemeDark: value),
                          ),
                        ),
                      ],
                    )
                  : const Center(child: CircularProgressIndicator()),
            ),
          ],
        );
      },
    );
  }

  void _syncTabFromSettings() {
    if (!_controller.isLoaded) {
      return;
    }
    final target = _controller.settings.settingsTabIndex.clamp(
      0,
      _tabs.length - 1,
    );
    if (_tabController.index != target) {
      _tabController.index = target;
    }
  }

  void _handleTabChanged() {
    if (_tabController.indexIsChanging) {
      return;
    }
    final index = _tabController.index;
    if (_controller.settings.settingsTabIndex == index) {
      return;
    }
    _controller.update((current) => current.copyWith(settingsTabIndex: index));
  }
}
