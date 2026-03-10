import 'package:flutter/material.dart';

import 'package:cwatch/model/services_infra/logging/app_logger.dart';
import 'custom_ssh_host.dart';
import 'docker_workspace_state.dart';
import 'editor_preferences.dart';
import 'explorer_preferences.dart';
import 'server_workspace_state.dart';
import 'kubernetes_backend.dart';
import 'kubernetes_workspace_state.dart';
import 'terminal_preferences.dart';
import 'wsl_workspace_state.dart';
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
    this.closeToTray = false,
    this.appFontFamily,
    this.appThemeKey = 'blue-grey',
    this.uiDensity = AppUiDensity.compact,
    this.inputModePreference = InputModePreference.auto,
    this.sshClientBackend = SshClientBackend.platform,
    this.builtinSshHostKeyBindings = const {},
    this.customSshHosts = const [],
    this.customSshConfigPaths = const [],
    this.disabledSshConfigPaths = const [],
    this.disabledServerHosts = const [],
    this.serverDistroMap = const {},
    this.dockerDistroMap = const {},
    this.kubernetesConfigPaths = const [],
    this.kubernetesBackend = KubernetesBackend.cli,
    this.serverWorkspace,
    this.kubernetesWorkspace,
    this.wslWorkspace,
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
    this.fileTransferUploadConcurrency = 2,
    this.fileTransferDownloadConcurrency = 2,
    this.explorerRowHeight = 36,
    this.explorerShowBreadcrumbs = true,
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
  final bool closeToTray;
  final String? appFontFamily;
  final String appThemeKey;
  final AppUiDensity uiDensity;
  final InputModePreference inputModePreference;
  final SshClientBackend sshClientBackend;
  final Map<String, String> builtinSshHostKeyBindings;
  final List<CustomSshHost> customSshHosts;
  final List<String> customSshConfigPaths;
  final List<String> disabledSshConfigPaths;
  final List<String> disabledServerHosts;
  final Map<String, String> serverDistroMap;
  final Map<String, String> dockerDistroMap;
  final List<String> kubernetesConfigPaths;
  final KubernetesBackend kubernetesBackend;
  final ServerWorkspaceState? serverWorkspace;
  final KubernetesWorkspaceState? kubernetesWorkspace;
  final WslWorkspaceState? wslWorkspace;
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
  final int fileTransferUploadConcurrency;
  final int fileTransferDownloadConcurrency;
  final double explorerRowHeight;
  final bool explorerShowBreadcrumbs;

  int get dockerLogsTailClamped => _sanitizeTailLines(dockerLogsTail);
  TerminalPreferences get terminalPreferences => TerminalPreferences(
    fontFamily: terminalFontFamily,
    fontSize: terminalFontSize,
    lineHeight: terminalLineHeight,
    paddingX: terminalPaddingX,
    paddingY: terminalPaddingY,
    themeDark: terminalThemeDark,
    themeLight: terminalThemeLight,
  );
  EditorPreferences get editorPreferences => EditorPreferences(
    themeLight: editorThemeLight,
    themeDark: editorThemeDark,
    fontFamily: editorFontFamily,
    fontSize: editorFontSize,
    lineHeight: editorLineHeight,
  );
  ExplorerPreferences get explorerPreferences => ExplorerPreferences(
    rowHeight: explorerRowHeight,
    showBreadcrumbs: explorerShowBreadcrumbs,
  );

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
    bool? closeToTray,
    String? appFontFamily,
    String? appThemeKey,
    AppUiDensity? uiDensity,
    InputModePreference? inputModePreference,
    SshClientBackend? sshClientBackend,
    Map<String, String>? builtinSshHostKeyBindings,
    List<CustomSshHost>? customSshHosts,
    List<String>? customSshConfigPaths,
    List<String>? disabledSshConfigPaths,
    List<String>? disabledServerHosts,
    Map<String, String>? serverDistroMap,
    Map<String, String>? dockerDistroMap,
    List<String>? kubernetesConfigPaths,
    KubernetesBackend? kubernetesBackend,
    ServerWorkspaceState? serverWorkspace,
    KubernetesWorkspaceState? kubernetesWorkspace,
    WslWorkspaceState? wslWorkspace,
    Map<String, String>? shortcutBindings,
    String? editorThemeLight,
    String? editorThemeDark,
    String? editorFontFamily,
    double? editorFontSize,
    double? editorLineHeight,
    EditorPreferences? editorPreferences,
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
    TerminalPreferences? terminalPreferences,
    int? fileTransferUploadConcurrency,
    int? fileTransferDownloadConcurrency,
    double? explorerRowHeight,
    bool? explorerShowBreadcrumbs,
    ExplorerPreferences? explorerPreferences,
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
      closeToTray: closeToTray ?? this.closeToTray,
      appFontFamily: appFontFamily ?? this.appFontFamily,
      appThemeKey: appThemeKey ?? this.appThemeKey,
      uiDensity: uiDensity ?? this.uiDensity,
      inputModePreference: inputModePreference ?? this.inputModePreference,
      sshClientBackend: sshClientBackend ?? this.sshClientBackend,
      builtinSshHostKeyBindings:
          builtinSshHostKeyBindings ?? this.builtinSshHostKeyBindings,
      customSshHosts: customSshHosts ?? this.customSshHosts,
      customSshConfigPaths: customSshConfigPaths ?? this.customSshConfigPaths,
      disabledSshConfigPaths:
          disabledSshConfigPaths ?? this.disabledSshConfigPaths,
      disabledServerHosts: disabledServerHosts ?? this.disabledServerHosts,
      serverDistroMap: serverDistroMap ?? this.serverDistroMap,
      dockerDistroMap: dockerDistroMap ?? this.dockerDistroMap,
      kubernetesConfigPaths:
          kubernetesConfigPaths ?? this.kubernetesConfigPaths,
      kubernetesBackend: kubernetesBackend ?? this.kubernetesBackend,
      serverWorkspace: serverWorkspace ?? this.serverWorkspace,
      kubernetesWorkspace: kubernetesWorkspace ?? this.kubernetesWorkspace,
      wslWorkspace: wslWorkspace ?? this.wslWorkspace,
      shortcutBindings: shortcutBindings ?? this.shortcutBindings,
      editorThemeLight:
          editorPreferences?.themeLight ??
          editorThemeLight ??
          this.editorThemeLight,
      editorThemeDark:
          editorPreferences?.themeDark ??
          editorThemeDark ??
          this.editorThemeDark,
      editorFontFamily:
          editorPreferences?.fontFamily ??
          editorFontFamily ??
          this.editorFontFamily,
      editorFontSize:
          editorPreferences?.fontSize ??
          editorFontSize ??
          this.editorFontSize,
      editorLineHeight:
          editorPreferences?.lineHeight ??
          editorLineHeight ??
          this.editorLineHeight,
      dockerRemoteHosts: dockerRemoteHosts ?? this.dockerRemoteHosts,
      dockerSelectedContext:
          dockerSelectedContext ?? this.dockerSelectedContext,
      dockerWorkspace: dockerWorkspace ?? this.dockerWorkspace,
      dockerLogsTail: _sanitizeTailLines(dockerLogsTail ?? this.dockerLogsTail),
      terminalFontFamily:
          terminalPreferences?.fontFamily ??
          terminalFontFamily ??
          this.terminalFontFamily,
      terminalFontSize:
          terminalPreferences?.fontSize ??
          terminalFontSize ??
          this.terminalFontSize,
      terminalLineHeight:
          terminalPreferences?.lineHeight ??
          terminalLineHeight ??
          this.terminalLineHeight,
      terminalPaddingX:
          terminalPreferences?.paddingX ??
          terminalPaddingX ??
          this.terminalPaddingX,
      terminalPaddingY:
          terminalPreferences?.paddingY ??
          terminalPaddingY ??
          this.terminalPaddingY,
      terminalThemeDark:
          terminalPreferences?.themeDark ??
          terminalThemeDark ??
          this.terminalThemeDark,
      terminalThemeLight:
          terminalPreferences?.themeLight ??
          terminalThemeLight ??
          this.terminalThemeLight,
      fileTransferUploadConcurrency: _sanitizeTransferConcurrency(
        fileTransferUploadConcurrency ?? this.fileTransferUploadConcurrency,
      ),
      fileTransferDownloadConcurrency: _sanitizeTransferConcurrency(
        fileTransferDownloadConcurrency ?? this.fileTransferDownloadConcurrency,
      ),
      explorerRowHeight: _sanitizeExplorerRowHeight(
        explorerPreferences?.rowHeight ??
            explorerRowHeight ??
            this.explorerRowHeight,
      ),
      explorerShowBreadcrumbs:
          explorerPreferences?.showBreadcrumbs ??
          explorerShowBreadcrumbs ??
          this.explorerShowBreadcrumbs,
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
      closeToTray: json['closeToTray'] as bool? ?? false,
      appFontFamily: json['appFontFamily'] as String?,
      appThemeKey: json['appThemeKey'] as String? ?? 'blue-grey',
      uiDensity: AppUiDensityParsing.fromJson(json['uiDensity'] as String?),
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
      disabledServerHosts:
          (json['disabledServerHosts'] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          const [],
      serverDistroMap:
          (json['serverDistroMap'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(key, value.toString()),
          ) ??
          const {},
      dockerDistroMap:
          (json['dockerDistroMap'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(key, value.toString()),
          ) ??
          const {},
      kubernetesConfigPaths:
          (json['kubernetesConfigPaths'] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          const [],
      kubernetesBackend: KubernetesBackendParsing.fromJson(
        json['kubernetesBackend'] as String?,
      ),
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
          } catch (error, stackTrace) {
            AppLogger().warn(
              'Failed to parse kubernetes workspace state',
              tag: 'Settings',
              error: error,
              stackTrace: stackTrace,
            );
            return null;
          }
        }
        return null;
      }(),
      wslWorkspace: () {
        final raw = json['wslWorkspace'];
        if (raw is Map<String, dynamic>) {
          try {
            return WslWorkspaceState.fromJson(raw);
          } catch (error, stackTrace) {
            AppLogger().warn(
              'Failed to parse wsl workspace state',
              tag: 'Settings',
              error: error,
              stackTrace: stackTrace,
            );
            return null;
          }
        }
        return null;
      }(),
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
          } catch (error, stackTrace) {
            AppLogger().warn(
              'Failed to parse docker workspace state',
              tag: 'Settings',
              error: error,
              stackTrace: stackTrace,
            );
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
      fileTransferUploadConcurrency: _sanitizeTransferConcurrency(
        (json['fileTransferUploadConcurrency'] as num?)?.toInt() ?? 2,
      ),
      fileTransferDownloadConcurrency: _sanitizeTransferConcurrency(
        (json['fileTransferDownloadConcurrency'] as num?)?.toInt() ?? 2,
      ),
      dockerLogsTail: _sanitizeTailLines(
        (json['dockerLogsTail'] as num?)?.toInt() ?? 200,
      ),
      explorerRowHeight: _sanitizeExplorerRowHeight(
        (json['explorerRowHeight'] as num?)?.toDouble() ?? 36,
      ),
      explorerShowBreadcrumbs: json['explorerShowBreadcrumbs'] as bool? ?? true,
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
      'closeToTray': closeToTray,
      if (appFontFamily != null) 'appFontFamily': appFontFamily,
      'appThemeKey': appThemeKey,
      'uiDensity': uiDensity.name,
      'inputModePreference': inputModePreference.name,
      'sshClientBackend': sshClientBackend.name,
      'builtinSshHostKeyBindings': builtinSshHostKeyBindings,
      'customSshHosts': customSshHosts.map((h) => h.toJson()).toList(),
      'customSshConfigPaths': customSshConfigPaths,
      'disabledSshConfigPaths': disabledSshConfigPaths,
      'disabledServerHosts': disabledServerHosts,

      'kubernetesConfigPaths': kubernetesConfigPaths,
      'kubernetesBackend': kubernetesBackend.name,
      'shortcutBindings': shortcutBindings,
      if (editorThemeLight != null) 'editorThemeLight': editorThemeLight,
      if (editorThemeDark != null) 'editorThemeDark': editorThemeDark,
      if (editorFontFamily != null) 'editorFontFamily': editorFontFamily,
      'editorFontSize': editorFontSize,
      'editorLineHeight': editorLineHeight,

      if (dockerSelectedContext != null)
        'dockerSelectedContext': dockerSelectedContext,
      'dockerLogsTail': dockerLogsTailClamped,
      if (terminalFontFamily != null) 'terminalFontFamily': terminalFontFamily,
      'terminalFontSize': terminalFontSize,
      'terminalLineHeight': terminalLineHeight,
      'terminalPaddingX': terminalPaddingX,
      'terminalPaddingY': terminalPaddingY,
      'terminalThemeDark': terminalThemeDark,
      'terminalThemeLight': terminalThemeLight,
      'fileTransferUploadConcurrency': fileTransferUploadConcurrency,
      'fileTransferDownloadConcurrency': fileTransferDownloadConcurrency,
      'explorerRowHeight': explorerRowHeight,
      'explorerShowBreadcrumbs': explorerShowBreadcrumbs,
    };
  }

  static int _sanitizeTailLines(int value) {
    if (value < 0) return 0;
    if (value > 5000) return 5000;
    return value;
  }

  static int _sanitizeTransferConcurrency(int value) {
    if (value < 1) return 1;
    if (value > 15) return 15;
    return value;
  }

  static double _sanitizeExplorerRowHeight(double value) {
    if (value < 24) return 24;
    if (value > 88) return 88;
    return value;
  }
}

enum AppUiDensity { compact, comfy }

class AppUiDensityParsing {
  static AppUiDensity fromJson(String? value) {
    switch (value) {
      case 'comfy':
        return AppUiDensity.comfy;
      case 'compact':
      default:
        return AppUiDensity.compact;
    }
  }
}
