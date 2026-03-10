import 'dart:async';

import 'package:flutter/material.dart';

import 'package:cwatch/controller/adapters/settings_ui_adapter.dart';
import 'package:cwatch/controller/controllers/settings_controller.dart';
import 'package:cwatch/view/core/navigation/command_palette_registry.dart';
import 'package:cwatch/view/core/navigation/tab_navigation_registry.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/services_infra/settings/app_settings_controller.dart';
import 'package:cwatch/model/services_infra/settings/settings_view_session_storage.dart';
import 'package:cwatch/model/services_infra/ssh/builtin/builtin_ssh_key_service.dart';
import 'package:cwatch/model/services_infra/ssh/ssh_shell_factory.dart';
import 'package:cwatch/model/shared/theme/nerd_fonts.dart';
import 'package:cwatch/view/shared/widgets/section_nav_bar.dart';
import 'package:cwatch/controller/di/bindings/settings_binding.dart';
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
  final SettingsViewSessionStorage _sessionStorage =
      SettingsViewSessionStorage();
  late final SettingsUiAdapter _uiAdapter;
  late final SettingsController _controller;
  late final TabController _tabController;
  late final TabNavigationHandle _tabNavigator;
  late final CommandPaletteHandle _commandPaletteHandle;
  bool _didLoadInitialTab = false;

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
    unawaited(_loadInitialTabFromSession());
  }

  @override
  void dispose() {
    TabNavigationRegistry.instance.unregister('settings', _tabNavigator);
    CommandPaletteRegistry.instance.unregister(
      'settings',
      _commandPaletteHandle,
    );
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
              enableWindowDrag: !settings.shellPreferences.useSystemDecorations,
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
                                current.copyWith(
                                  dockerPreferences:
                                      current.dockerPreferences.copyWith(
                                        logsTail: value,
                                      ),
                                ),
                          ),
                        ),
                        KubernetesSettingsTab(
                          settings: settings,
                          settingsController: _controller,
                        ),
                        TerminalSettingsTab(
                          settings: settings,
                          settingsController: _controller,
                          fontFamily: settings.terminalPreferences.fontFamily,
                          fontSize: settings.terminalPreferences.fontSize,
                          lineHeight: settings.terminalPreferences.lineHeight,
                          paddingX: settings.terminalPreferences.paddingX,
                          paddingY: settings.terminalPreferences.paddingY,
                          darkTheme: settings.terminalPreferences.themeDark,
                          lightTheme: settings.terminalPreferences.themeLight,
                          onFontFamilyChanged: (value) => _controller.update(
                            (current) => current.copyWith(
                              terminalPreferences:
                                  current.terminalPreferences.copyWith(
                                    fontFamily: value.trim().isEmpty
                                        ? null
                                        : value.trim(),
                                  ),
                            ),
                          ),
                          onFontSizeChanged: (value) => _controller.update(
                            (current) => current.copyWith(
                              terminalPreferences:
                                  current.terminalPreferences.copyWith(
                                    fontSize: value,
                                  ),
                            ),
                          ),
                          onLineHeightChanged: (value) => _controller.update(
                            (current) => current.copyWith(
                              terminalPreferences:
                                  current.terminalPreferences.copyWith(
                                    lineHeight: value,
                                  ),
                            ),
                          ),
                          onPaddingXChanged: (value) => _controller.update(
                            (current) => current.copyWith(
                              terminalPreferences:
                                  current.terminalPreferences.copyWith(
                                    paddingX: value,
                                  ),
                            ),
                          ),
                          onPaddingYChanged: (value) => _controller.update(
                            (current) => current.copyWith(
                              terminalPreferences:
                                  current.terminalPreferences.copyWith(
                                    paddingY: value,
                                  ),
                            ),
                          ),
                          onDarkThemeChanged: (value) => _controller.update(
                            (current) => current.copyWith(
                              terminalPreferences:
                                  current.terminalPreferences.copyWith(
                                    themeDark: value,
                                  ),
                            ),
                          ),
                          onLightThemeChanged: (value) => _controller.update(
                            (current) => current.copyWith(
                              terminalPreferences:
                                  current.terminalPreferences.copyWith(
                                    themeLight: value,
                                  ),
                            ),
                          ),
                        ),
                        EditorSettingsTab(
                          settings: settings,
                          settingsController: _controller,
                          fontFamily: settings.editorPreferences.fontFamily,
                          fontSize: settings.editorPreferences.fontSize,
                          lineHeight: settings.editorPreferences.lineHeight,
                          onFontFamilyChanged: (value) => _controller.update(
                            (current) => current.copyWith(
                              editorPreferences:
                                  current.editorPreferences.copyWith(
                                    fontFamily: value.trim().isEmpty
                                        ? null
                                        : value.trim(),
                                  ),
                            ),
                          ),
                          onFontSizeChanged: (value) => _controller.update(
                            (current) => current.copyWith(
                              editorPreferences:
                                  current.editorPreferences.copyWith(
                                    fontSize: value,
                                  ),
                            ),
                          ),
                          onLineHeightChanged: (value) => _controller.update(
                            (current) => current.copyWith(
                              editorPreferences:
                                  current.editorPreferences.copyWith(
                                    lineHeight: value,
                                  ),
                            ),
                          ),
                          lightTheme: settings.editorPreferences.themeLight,
                          darkTheme: settings.editorPreferences.themeDark,
                          onLightThemeChanged: (value) => _controller.update(
                            (current) => current.copyWith(
                              editorPreferences:
                                  current.editorPreferences.copyWith(
                                    themeLight: value,
                                  ),
                            ),
                          ),
                          onDarkThemeChanged: (value) => _controller.update(
                            (current) => current.copyWith(
                              editorPreferences:
                                  current.editorPreferences.copyWith(
                                    themeDark: value,
                                  ),
                            ),
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

  Future<void> _loadInitialTabFromSession() async {
    final target = await _sessionStorage.loadTabIndex();
    if (!mounted) {
      return;
    }
    final clamped = target.clamp(0, _tabs.length - 1);
    _didLoadInitialTab = true;
    if (_tabController.index != clamped) {
      _tabController.index = clamped;
    }
  }

  void _handleTabChanged() {
    if (_tabController.indexIsChanging || !_didLoadInitialTab) {
      return;
    }
    unawaited(_sessionStorage.saveTabIndex(_tabController.index));
  }
}
