import 'package:flutter/material.dart';

import 'package:cwatch/models/ssh_host.dart';
import 'package:cwatch/services/ssh/remote_command_logging.dart';
import 'package:cwatch/services/settings/app_settings_controller.dart';
import 'package:cwatch/shared/theme/nerd_fonts.dart';
import 'package:cwatch/shared/widgets/section_nav_bar.dart';
import 'package:cwatch/services/ssh/builtin/builtin_ssh_key_service.dart';
import 'container_settings_tabs.dart';
import 'debug_logs_tab.dart';
import 'general_settings_tab.dart';
import 'servers_settings_tab.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({
    required this.controller,
    required this.hostsFuture,
    required this.keyService,
    required this.commandLog,
    this.leading,
    super.key,
  });

  final AppSettingsController controller;
  final Future<List<SshHost>> hostsFuture;
  final BuiltInSshKeyService keyService;
  final RemoteCommandLogController commandLog;
  final Widget? leading;

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final VoidCallback _settingsListener;

  static const _tabs = [
    Tab(text: 'General'),
    Tab(text: 'Servers'),
    Tab(text: 'Docker'),
    Tab(text: 'Kubernetes'),
    Tab(text: 'Debug Logs'),
  ];

  static final _tabIcons = [
    Icons.settings_outlined, // General
    Icons.storage, // Servers
    NerdIcon.docker.data, // Docker
    NerdIcon.kubernetes.data, // Kubernetes
    Icons.bug_report_outlined, // Debug Logs
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_handleTabChanged);
    _settingsListener = _syncTabFromSettings;
    widget.controller.addListener(_settingsListener);
    _syncTabFromSettings();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_settingsListener);
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final settings = widget.controller.settings;
        return Column(
          children: [
            SectionNavBar(
              title: 'Settings',
              tabs: _tabs,
              tabIcons: _tabIcons,
              controller: _tabController,
              showTitle: false,
              leading: widget.leading,
            ),
            Expanded(
              child: widget.controller.isLoaded
                  ? TabBarView(
                      controller: _tabController,
                      children: [
                        GeneralSettingsTab(
                          selectedTheme: settings.themeMode,
                          debugMode: settings.debugMode,
                          zoomFactor: settings.zoomFactor,
                          onThemeChanged: (mode) => widget.controller.update(
                            (current) => current.copyWith(themeMode: mode),
                          ),
                          onDebugModeChanged: (value) =>
                              widget.controller.update(
                                (current) => current.copyWith(debugMode: value),
                              ),
                          onZoomChanged: (value) => widget.controller.update(
                            (current) => current.copyWith(zoomFactor: value),
                          ),
                          appFontFamily: settings.appFontFamily,
                          onAppFontFamilyChanged: (value) =>
                              widget.controller.update(
                                (current) => current.copyWith(
                                  appFontFamily: value.trim().isEmpty
                                      ? null
                                      : value.trim(),
                                ),
                              ),
                          appThemeKey: settings.appThemeKey,
                          onAppThemeChanged: (value) =>
                              widget.controller.update(
                                (current) =>
                                    current.copyWith(appThemeKey: value),
                              ),
                          terminalFontFamily: settings.terminalFontFamily,
                          terminalFontSize: settings.terminalFontSize,
                          terminalLineHeight: settings.terminalLineHeight,
                          terminalThemeDark: settings.terminalThemeDark,
                          terminalThemeLight: settings.terminalThemeLight,
                          onTerminalFontFamilyChanged: (value) =>
                              widget.controller.update(
                                (current) => current.copyWith(
                                  terminalFontFamily: value.trim().isEmpty
                                      ? null
                                      : value.trim(),
                                ),
                              ),
                          onTerminalFontSizeChanged: (value) =>
                              widget.controller.update(
                                (current) =>
                                    current.copyWith(terminalFontSize: value),
                              ),
                          onTerminalLineHeightChanged: (value) =>
                              widget.controller.update(
                                (current) =>
                                    current.copyWith(terminalLineHeight: value),
                              ),
                          onTerminalThemeDarkChanged: (value) =>
                              widget.controller.update(
                                (current) =>
                                    current.copyWith(terminalThemeDark: value),
                              ),
                          onTerminalThemeLightChanged: (value) =>
                              widget.controller.update(
                                (current) =>
                                    current.copyWith(terminalThemeLight: value),
                              ),
                          editorThemeLight: settings.editorThemeLight,
                          editorThemeDark: settings.editorThemeDark,
                          onEditorThemeLightChanged: (value) =>
                              widget.controller.update(
                                (current) =>
                                    current.copyWith(editorThemeLight: value),
                              ),
                          onEditorThemeDarkChanged: (value) =>
                              widget.controller.update(
                                (current) =>
                                    current.copyWith(editorThemeDark: value),
                              ),
                          editorFontFamily: settings.editorFontFamily,
                          editorFontSize: settings.editorFontSize,
                          editorLineHeight: settings.editorLineHeight,
                          onEditorFontFamilyChanged: (value) =>
                              widget.controller.update(
                                (current) => current.copyWith(
                                  editorFontFamily: value.trim().isEmpty
                                      ? null
                                      : value.trim(),
                                ),
                              ),
                          onEditorFontSizeChanged: (value) =>
                              widget.controller.update(
                                (current) =>
                                    current.copyWith(editorFontSize: value),
                              ),
                          onEditorLineHeightChanged: (value) =>
                              widget.controller.update(
                                (current) =>
                                    current.copyWith(editorLineHeight: value),
                              ),
                        ),
                        ServersSettingsTab(
                          key: const ValueKey('servers_settings_tab'),
                          controller: widget.controller,
                          hostsFuture: widget.hostsFuture,
                          keyService: widget.keyService,
                        ),
                        DockerSettingsTab(),
                        KubernetesSettingsTab(),
                        DebugLogsTab(
                          logController: widget.commandLog,
                          debugEnabled: settings.debugMode,
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
    if (!widget.controller.isLoaded) {
      return;
    }
    final target = widget.controller.settings.settingsTabIndex.clamp(
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
    if (widget.controller.settings.settingsTabIndex == index) {
      return;
    }
    widget.controller.update(
      (current) => current.copyWith(settingsTabIndex: index),
    );
  }
}
