import 'package:flutter/material.dart';

import 'custom_ssh_host.dart';
import 'docker_workspace_state.dart';
import 'server_workspace_state.dart';
import 'kubernetes_workspace_state.dart';
import 'ssh_client_backend.dart';
import 'input_mode_preference.dart';

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
    this.shellSidebarPlacement = 'dynamic',
    this.windowUseSystemDecorations = true,
    this.appFontFamily,
    this.appThemeKey = 'blue-grey',
    this.inputModePreference = InputModePreference.auto,
    this.sshClientBackend = SshClientBackend.platform,
    this.builtinSshHostKeyBindings = const {},
    this.customSshHosts = const [],
    this.customSshConfigPaths = const [],
    this.disabledSshConfigPaths = const [],
    this.kubernetesConfigPaths = const [],
    this.serverWorkspace,
    this.kubernetesWorkspace,
    this.settingsTabIndex = 0,
    this.shortcutBindings = const {},
    this.editorThemeLight,
    this.editorThemeDark,
    this.editorFontFamily,
    this.editorFontSize = 14,
    this.editorLineHeight = 1.35,
    this.dockerRemoteHosts = const [],
    this.dockerSelectedContext,
    this.dockerWorkspace,
    this.dockerLogsTail = 200,
    this.terminalFontFamily = 'JetBrainsMono Nerd Font',
    this.terminalFontSize = 14,
    this.terminalLineHeight = 1.15,
    this.terminalPaddingX = 8,
    this.terminalPaddingY = 10,
    this.terminalThemeDark = 'dracula',
    this.terminalThemeLight = 'solarized-light',
  });

  final ThemeMode themeMode;
  final bool debugMode;
  final double zoomFactor;
  final bool serverAutoRefresh;
  final bool serverShowOffline;
  final double? shellSidebarWidth;
  final String? shellDestination;
  final bool shellSidebarCollapsed;
  final String? shellSidebarPlacement;
  final bool windowUseSystemDecorations;
  final String? appFontFamily;
  final String appThemeKey;
  final InputModePreference inputModePreference;
  final SshClientBackend sshClientBackend;
  final Map<String, String> builtinSshHostKeyBindings;
  final List<CustomSshHost> customSshHosts;
  final List<String> customSshConfigPaths;
  final List<String> disabledSshConfigPaths;
  final List<String> kubernetesConfigPaths;
  final ServerWorkspaceState? serverWorkspace;
  final KubernetesWorkspaceState? kubernetesWorkspace;
  final int settingsTabIndex;
  final Map<String, String> shortcutBindings;
  final String? editorThemeLight;
  final String? editorThemeDark;
  final String? editorFontFamily;
  final double editorFontSize;
  final double editorLineHeight;
  final List<String> dockerRemoteHosts;
  final String? dockerSelectedContext;
  final DockerWorkspaceState? dockerWorkspace;
  final int dockerLogsTail;
  final String? terminalFontFamily;
  final double terminalFontSize;
  final double terminalLineHeight;
  final double terminalPaddingX;
  final double terminalPaddingY;
  final String terminalThemeDark;
  final String terminalThemeLight;

  int get dockerLogsTailClamped => _sanitizeTailLines(dockerLogsTail);

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? debugMode,
    double? zoomFactor,
    bool? serverAutoRefresh,
    bool? serverShowOffline,
    double? shellSidebarWidth,
    String? shellDestination,
    bool? shellSidebarCollapsed,
    String? shellSidebarPlacement,
    bool? windowUseSystemDecorations,
    String? appFontFamily,
    String? appThemeKey,
    InputModePreference? inputModePreference,
    SshClientBackend? sshClientBackend,
    Map<String, String>? builtinSshHostKeyBindings,
    List<CustomSshHost>? customSshHosts,
    List<String>? customSshConfigPaths,
    List<String>? disabledSshConfigPaths,
    List<String>? kubernetesConfigPaths,
    ServerWorkspaceState? serverWorkspace,
    KubernetesWorkspaceState? kubernetesWorkspace,
    int? settingsTabIndex,
    Map<String, String>? shortcutBindings,
    String? editorThemeLight,
    String? editorThemeDark,
    String? editorFontFamily,
    double? editorFontSize,
    double? editorLineHeight,
    List<String>? dockerRemoteHosts,
    String? dockerSelectedContext,
    DockerWorkspaceState? dockerWorkspace,
    int? dockerLogsTail,
    String? terminalFontFamily,
    double? terminalFontSize,
    double? terminalLineHeight,
    double? terminalPaddingX,
    double? terminalPaddingY,
    String? terminalThemeDark,
    String? terminalThemeLight,
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
      shellSidebarPlacement:
          shellSidebarPlacement ?? this.shellSidebarPlacement,
      windowUseSystemDecorations:
          windowUseSystemDecorations ?? this.windowUseSystemDecorations,
      appFontFamily: appFontFamily ?? this.appFontFamily,
      appThemeKey: appThemeKey ?? this.appThemeKey,
      inputModePreference: inputModePreference ?? this.inputModePreference,
      sshClientBackend: sshClientBackend ?? this.sshClientBackend,
      builtinSshHostKeyBindings:
          builtinSshHostKeyBindings ?? this.builtinSshHostKeyBindings,
      customSshHosts: customSshHosts ?? this.customSshHosts,
      customSshConfigPaths: customSshConfigPaths ?? this.customSshConfigPaths,
      disabledSshConfigPaths:
          disabledSshConfigPaths ?? this.disabledSshConfigPaths,
      kubernetesConfigPaths:
          kubernetesConfigPaths ?? this.kubernetesConfigPaths,
      serverWorkspace: serverWorkspace ?? this.serverWorkspace,
      kubernetesWorkspace: kubernetesWorkspace ?? this.kubernetesWorkspace,
      settingsTabIndex: settingsTabIndex ?? this.settingsTabIndex,
      shortcutBindings: shortcutBindings ?? this.shortcutBindings,
      editorThemeLight: editorThemeLight ?? this.editorThemeLight,
      editorThemeDark: editorThemeDark ?? this.editorThemeDark,
      editorFontFamily: editorFontFamily ?? this.editorFontFamily,
      editorFontSize: editorFontSize ?? this.editorFontSize,
      editorLineHeight: editorLineHeight ?? this.editorLineHeight,
      dockerRemoteHosts: dockerRemoteHosts ?? this.dockerRemoteHosts,
      dockerSelectedContext:
          dockerSelectedContext ?? this.dockerSelectedContext,
      dockerWorkspace: dockerWorkspace ?? this.dockerWorkspace,
      dockerLogsTail: _sanitizeTailLines(dockerLogsTail ?? this.dockerLogsTail),
      terminalFontFamily: terminalFontFamily ?? this.terminalFontFamily,
      terminalFontSize: terminalFontSize ?? this.terminalFontSize,
      terminalLineHeight: terminalLineHeight ?? this.terminalLineHeight,
      terminalPaddingX: terminalPaddingX ?? this.terminalPaddingX,
      terminalPaddingY: terminalPaddingY ?? this.terminalPaddingY,
      terminalThemeDark: terminalThemeDark ?? this.terminalThemeDark,
      terminalThemeLight: terminalThemeLight ?? this.terminalThemeLight,
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
      shellSidebarPlacement:
          json['shellSidebarPlacement'] as String? ?? 'dynamic',
      windowUseSystemDecorations:
          json['windowUseSystemDecorations'] as bool? ?? true,
      appFontFamily: json['appFontFamily'] as String?,
      appThemeKey: json['appThemeKey'] as String? ?? 'blue-grey',
      inputModePreference: InputModePreferenceParsing.fromJson(
        json['inputModePreference'] as String?,
      ),
      sshClientBackend: SshClientBackendParsing.fromJson(
        json['sshClientBackend'] as String?,
      ),
      builtinSshHostKeyBindings: parseBindings(
        json['builtinSshHostKeyBindings'] as Map<String, dynamic>?,
      ),
      customSshHosts:
          (json['customSshHosts'] as List<dynamic>?)
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
      kubernetesConfigPaths:
          (json['kubernetesConfigPaths'] as List<dynamic>?)
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
      kubernetesWorkspace: () {
        final raw = json['kubernetesWorkspace'];
        if (raw is Map<String, dynamic>) {
          try {
            return KubernetesWorkspaceState.fromJson(raw);
          } catch (_) {
            return null;
          }
        }
        return null;
      }(),
      settingsTabIndex: (json['settingsTabIndex'] as num?)?.toInt() ?? 0,
      shortcutBindings:
          (json['shortcutBindings'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(key, value.toString()),
          ) ??
          const {},
      editorThemeLight: json['editorThemeLight'] as String?,
      editorThemeDark: json['editorThemeDark'] as String?,
      editorFontFamily: json['editorFontFamily'] as String?,
      editorFontSize: (json['editorFontSize'] as num?)?.toDouble() ?? 14,
      editorLineHeight: (json['editorLineHeight'] as num?)?.toDouble() ?? 1.35,
      dockerRemoteHosts:
          (json['dockerRemoteHosts'] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          const [],
      dockerSelectedContext: json['dockerSelectedContext'] as String?,
      dockerWorkspace: () {
        final raw = json['dockerWorkspace'];
        if (raw is Map<String, dynamic>) {
          try {
            return DockerWorkspaceState.fromJson(raw);
          } catch (_) {
            return null;
          }
        }
        return null;
      }(),
      terminalFontFamily:
          json['terminalFontFamily'] as String? ?? 'JetBrainsMono Nerd Font',
      terminalFontSize: (json['terminalFontSize'] as num?)?.toDouble() ?? 14,
      terminalLineHeight:
          (json['terminalLineHeight'] as num?)?.toDouble() ?? 1.15,
      terminalPaddingX: (json['terminalPaddingX'] as num?)?.toDouble() ?? 8,
      terminalPaddingY: (json['terminalPaddingY'] as num?)?.toDouble() ?? 10,
      terminalThemeDark: json['terminalThemeDark'] as String? ?? 'dracula',
      terminalThemeLight:
          json['terminalThemeLight'] as String? ?? 'solarized-light',
      dockerLogsTail: _sanitizeTailLines(
        (json['dockerLogsTail'] as num?)?.toInt() ?? 200,
      ),
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
      'shellSidebarPlacement': shellSidebarPlacement,
      'windowUseSystemDecorations': windowUseSystemDecorations,
      if (appFontFamily != null) 'appFontFamily': appFontFamily,
      'appThemeKey': appThemeKey,
      'inputModePreference': inputModePreference.name,
      'sshClientBackend': sshClientBackend.name,
      'builtinSshHostKeyBindings': builtinSshHostKeyBindings,
      'customSshHosts': customSshHosts.map((h) => h.toJson()).toList(),
      'customSshConfigPaths': customSshConfigPaths,
      'disabledSshConfigPaths': disabledSshConfigPaths,
      'kubernetesConfigPaths': kubernetesConfigPaths,
      if (serverWorkspace != null) 'serverWorkspace': serverWorkspace!.toJson(),
      if (kubernetesWorkspace != null)
        'kubernetesWorkspace': kubernetesWorkspace!.toJson(),
      'settingsTabIndex': settingsTabIndex,
      'shortcutBindings': shortcutBindings,
      if (editorThemeLight != null) 'editorThemeLight': editorThemeLight,
      if (editorThemeDark != null) 'editorThemeDark': editorThemeDark,
      if (editorFontFamily != null) 'editorFontFamily': editorFontFamily,
      'editorFontSize': editorFontSize,
      'editorLineHeight': editorLineHeight,
      'dockerRemoteHosts': dockerRemoteHosts,
      if (dockerSelectedContext != null)
        'dockerSelectedContext': dockerSelectedContext,
      if (dockerWorkspace != null) 'dockerWorkspace': dockerWorkspace!.toJson(),
      'dockerLogsTail': dockerLogsTailClamped,
      if (terminalFontFamily != null) 'terminalFontFamily': terminalFontFamily,
      'terminalFontSize': terminalFontSize,
      'terminalLineHeight': terminalLineHeight,
      'terminalPaddingX': terminalPaddingX,
      'terminalPaddingY': terminalPaddingY,
      'terminalThemeDark': terminalThemeDark,
      'terminalThemeLight': terminalThemeLight,
    };
  }

  static int _sanitizeTailLines(int value) {
    if (value < 0) return 0;
    if (value > 5000) return 5000;
    return value;
  }
}
