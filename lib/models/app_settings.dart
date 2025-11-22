import 'package:flutter/material.dart';

import 'custom_ssh_host.dart';
import 'server_workspace_state.dart';
import 'ssh_client_backend.dart';

class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.debugMode = false,
    this.zoomFactor = 1.0,
    this.serverAutoRefresh = true,
    this.serverShowOffline = true,
    this.shellSidebarWidth,
    this.shellDestination,
    this.shellSidebarCollapsed = false,
    this.sshClientBackend = SshClientBackend.platform,
    this.builtinSshHostKeyBindings = const {},
    this.customSshHosts = const [],
    this.customSshConfigPaths = const [],
    this.disabledSshConfigPaths = const [],
    this.serverWorkspace,
    this.settingsTabIndex = 0,
    this.editorThemeLight,
    this.editorThemeDark,
  });

  final ThemeMode themeMode;
  final bool debugMode;
  final double zoomFactor;
  final bool serverAutoRefresh;
  final bool serverShowOffline;
  final double? shellSidebarWidth;
  final String? shellDestination;
  final bool shellSidebarCollapsed;
  final SshClientBackend sshClientBackend;
  final Map<String, String> builtinSshHostKeyBindings;
  final List<CustomSshHost> customSshHosts;
  final List<String> customSshConfigPaths;
  final List<String> disabledSshConfigPaths;
  final ServerWorkspaceState? serverWorkspace;
  final int settingsTabIndex;
  final String? editorThemeLight;
  final String? editorThemeDark;

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? debugMode,
    double? zoomFactor,
    bool? serverAutoRefresh,
    bool? serverShowOffline,
    double? shellSidebarWidth,
    String? shellDestination,
    bool? shellSidebarCollapsed,
    SshClientBackend? sshClientBackend,
    Map<String, String>? builtinSshHostKeyBindings,
    List<CustomSshHost>? customSshHosts,
    List<String>? customSshConfigPaths,
    List<String>? disabledSshConfigPaths,
    ServerWorkspaceState? serverWorkspace,
    int? settingsTabIndex,
    String? editorThemeLight,
    String? editorThemeDark,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      debugMode: debugMode ?? this.debugMode,
      zoomFactor: zoomFactor ?? this.zoomFactor,
      serverAutoRefresh: serverAutoRefresh ?? this.serverAutoRefresh,
      serverShowOffline: serverShowOffline ?? this.serverShowOffline,
      shellSidebarWidth: shellSidebarWidth ?? this.shellSidebarWidth,
      shellDestination: shellDestination ?? this.shellDestination,
      shellSidebarCollapsed:
          shellSidebarCollapsed ?? this.shellSidebarCollapsed,
      sshClientBackend: sshClientBackend ?? this.sshClientBackend,
      builtinSshHostKeyBindings:
          builtinSshHostKeyBindings ?? this.builtinSshHostKeyBindings,
      customSshHosts: customSshHosts ?? this.customSshHosts,
      customSshConfigPaths:
          customSshConfigPaths ?? this.customSshConfigPaths,
      disabledSshConfigPaths:
          disabledSshConfigPaths ?? this.disabledSshConfigPaths,
      serverWorkspace: serverWorkspace ?? this.serverWorkspace,
      settingsTabIndex: settingsTabIndex ?? this.settingsTabIndex,
      editorThemeLight: editorThemeLight ?? this.editorThemeLight,
      editorThemeDark: editorThemeDark ?? this.editorThemeDark,
    );
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    Map<String, String> parseBindings(Map<String, dynamic>? values) {
      if (values == null) {
        return {};
      }
      final bindings = <String, String>{};
      for (final entry in values.entries) {
        final value = entry.value;
        if (value is String) {
          bindings[entry.key] = value;
        }
      }
      return bindings;
    }

    ThemeMode parseThemeMode(String? value) {
      switch (value) {
        case 'light':
          return ThemeMode.light;
        case 'dark':
          return ThemeMode.dark;
        case 'system':
        default:
          return ThemeMode.system;
      }
    }

    return AppSettings(
      themeMode: parseThemeMode(json['themeMode'] as String?),
      debugMode: json['debugMode'] as bool? ?? false,
      zoomFactor: (json['zoomFactor'] as num?)?.toDouble() ?? 1.0,
      serverAutoRefresh: json['serverAutoRefresh'] as bool? ?? true,
      serverShowOffline: json['serverShowOffline'] as bool? ?? true,
      shellSidebarWidth: (json['shellSidebarWidth'] as num?)?.toDouble(),
      shellDestination: json['shellDestination'] as String?,
      shellSidebarCollapsed: json['shellSidebarCollapsed'] as bool? ?? false,
      sshClientBackend: SshClientBackendParsing.fromJson(
        json['sshClientBackend'] as String?,
      ),
      builtinSshHostKeyBindings: parseBindings(
        json['builtinSshHostKeyBindings'] as Map<String, dynamic>?,
      ),
      customSshHosts: (json['customSshHosts'] as List<dynamic>?)
              ?.map((e) => CustomSshHost.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      customSshConfigPaths:
          (json['customSshConfigPaths'] as List<dynamic>?)
                  ?.whereType<String>()
                  .toList() ??
              const [],
      disabledSshConfigPaths:
          (json['disabledSshConfigPaths'] as List<dynamic>?)
                  ?.whereType<String>()
                  .toList() ??
              const [],
      serverWorkspace: () {
        final raw = json['serverWorkspace'];
        if (raw is Map<String, dynamic>) {
          return ServerWorkspaceState.fromJson(raw);
        }
        return null;
      }(),
      settingsTabIndex: (json['settingsTabIndex'] as num?)?.toInt() ?? 0,
      editorThemeLight: json['editorThemeLight'] as String?,
      editorThemeDark: json['editorThemeDark'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'themeMode': themeMode.name,
      'debugMode': debugMode,
      'zoomFactor': zoomFactor,
      'serverAutoRefresh': serverAutoRefresh,
      'serverShowOffline': serverShowOffline,
      'shellSidebarWidth': shellSidebarWidth,
      'shellDestination': shellDestination,
      'shellSidebarCollapsed': shellSidebarCollapsed,
      'sshClientBackend': sshClientBackend.name,
      'builtinSshHostKeyBindings': builtinSshHostKeyBindings,
      'customSshHosts': customSshHosts.map((h) => h.toJson()).toList(),
      'customSshConfigPaths': customSshConfigPaths,
      'disabledSshConfigPaths': disabledSshConfigPaths,
      if (serverWorkspace != null) 'serverWorkspace': serverWorkspace!.toJson(),
      'settingsTabIndex': settingsTabIndex,
      if (editorThemeLight != null) 'editorThemeLight': editorThemeLight,
      if (editorThemeDark != null) 'editorThemeDark': editorThemeDark,
    };
  }
}
