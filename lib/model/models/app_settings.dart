import 'package:flutter/material.dart';

import 'package:cwatch/model/services_infra/logging/app_logger.dart';
import 'custom_ssh_host.dart';
import 'docker_preferences.dart';
import 'docker_workspace_state.dart';
import 'editor_preferences.dart';
import 'explorer_preferences.dart';
import 'kubernetes_preferences.dart';
import 'shell_preferences.dart';
import 'ssh_preferences.dart';
import 'ssh_client_backend.dart';
import 'server_workspace_state.dart';
import 'kubernetes_backend.dart';
import 'kubernetes_workspace_state.dart';
import 'terminal_preferences.dart';
import 'wsl_workspace_state.dart';
import 'input_mode_preference.dart';

class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.debugMode = false,
    this.zoomFactor = 1.0,
    this.serverAutoRefresh = true,
    this.serverShowOffline = true,
    this.shellPreferences = const ShellPreferences(),
    this.appFontFamily,
    this.appThemeKey = 'blue-grey',
    this.uiDensity = AppUiDensity.compact,
    this.inputModePreference = InputModePreference.auto,
    this.sshPreferences = const SshPreferences(),
    this.serverDistroMap = const {},
    this.dockerDistroMap = const {},
    this.kubernetesPreferences = const KubernetesPreferences(),
    this.serverWorkspace,
    this.kubernetesWorkspace,
    this.wslWorkspace,
    this.shortcutBindings = const {},
    this.editorPreferences = const EditorPreferences(),
    this.dockerPreferences = const DockerPreferences(),
    this.dockerWorkspace,
    this.terminalPreferences = const TerminalPreferences(),
    this.fileTransferUploadConcurrency = 2,
    this.fileTransferDownloadConcurrency = 2,
    this.explorerPreferences = const ExplorerPreferences(),
  });

  final ThemeMode themeMode;
  final bool debugMode;
  final double zoomFactor;
  final bool serverAutoRefresh;
  final bool serverShowOffline;
  final ShellPreferences shellPreferences;
  final String? appFontFamily;
  final String appThemeKey;
  final AppUiDensity uiDensity;
  final InputModePreference inputModePreference;
  final SshPreferences sshPreferences;
  final Map<String, String> serverDistroMap;
  final Map<String, String> dockerDistroMap;
  final KubernetesPreferences kubernetesPreferences;
  final ServerWorkspaceState? serverWorkspace;
  final KubernetesWorkspaceState? kubernetesWorkspace;
  final WslWorkspaceState? wslWorkspace;
  final Map<String, String> shortcutBindings;
  final EditorPreferences editorPreferences;
  final DockerPreferences dockerPreferences;
  final DockerWorkspaceState? dockerWorkspace;
  final TerminalPreferences terminalPreferences;
  final int fileTransferUploadConcurrency;
  final int fileTransferDownloadConcurrency;
  final ExplorerPreferences explorerPreferences;

  int get dockerLogsTailClamped =>
      _sanitizeTailLines(dockerPreferences.logsTail);

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? debugMode,
    double? zoomFactor,
    bool? serverAutoRefresh,
    bool? serverShowOffline,
    ShellPreferences? shellPreferences,
    String? appFontFamily,
    String? appThemeKey,
    AppUiDensity? uiDensity,
    InputModePreference? inputModePreference,
    SshPreferences? sshPreferences,
    Map<String, String>? serverDistroMap,
    Map<String, String>? dockerDistroMap,
    KubernetesPreferences? kubernetesPreferences,
    ServerWorkspaceState? serverWorkspace,
    KubernetesWorkspaceState? kubernetesWorkspace,
    WslWorkspaceState? wslWorkspace,
    Map<String, String>? shortcutBindings,
    EditorPreferences? editorPreferences,
    DockerPreferences? dockerPreferences,
    DockerWorkspaceState? dockerWorkspace,
    TerminalPreferences? terminalPreferences,
    int? fileTransferUploadConcurrency,
    int? fileTransferDownloadConcurrency,
    ExplorerPreferences? explorerPreferences,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      debugMode: debugMode ?? this.debugMode,
      zoomFactor: zoomFactor ?? this.zoomFactor,
      serverAutoRefresh: serverAutoRefresh ?? this.serverAutoRefresh,
      serverShowOffline: serverShowOffline ?? this.serverShowOffline,
      shellPreferences: shellPreferences ?? this.shellPreferences,
      appFontFamily: appFontFamily ?? this.appFontFamily,
      appThemeKey: appThemeKey ?? this.appThemeKey,
      uiDensity: uiDensity ?? this.uiDensity,
      inputModePreference: inputModePreference ?? this.inputModePreference,
      sshPreferences: sshPreferences ?? this.sshPreferences,
      serverDistroMap: serverDistroMap ?? this.serverDistroMap,
      dockerDistroMap: dockerDistroMap ?? this.dockerDistroMap,
      kubernetesPreferences:
          kubernetesPreferences ?? this.kubernetesPreferences,
      serverWorkspace: serverWorkspace ?? this.serverWorkspace,
      kubernetesWorkspace: kubernetesWorkspace ?? this.kubernetesWorkspace,
      wslWorkspace: wslWorkspace ?? this.wslWorkspace,
      shortcutBindings: shortcutBindings ?? this.shortcutBindings,
      editorPreferences: editorPreferences ?? this.editorPreferences,
      dockerPreferences: DockerPreferences(
        remoteHosts:
            (dockerPreferences ?? this.dockerPreferences).remoteHosts,
        selectedContext:
            (dockerPreferences ?? this.dockerPreferences).selectedContext,
        logsTail: _sanitizeTailLines(
          (dockerPreferences ?? this.dockerPreferences).logsTail,
        ),
      ),
      dockerWorkspace: dockerWorkspace ?? this.dockerWorkspace,
      terminalPreferences: terminalPreferences ?? this.terminalPreferences,
      fileTransferUploadConcurrency: _sanitizeTransferConcurrency(
        fileTransferUploadConcurrency ?? this.fileTransferUploadConcurrency,
      ),
      fileTransferDownloadConcurrency: _sanitizeTransferConcurrency(
        fileTransferDownloadConcurrency ?? this.fileTransferDownloadConcurrency,
      ),
      explorerPreferences: ExplorerPreferences(
        rowHeight: _sanitizeExplorerRowHeight(
          (explorerPreferences ?? this.explorerPreferences).rowHeight,
        ),
        showBreadcrumbs:
            (explorerPreferences ?? this.explorerPreferences).showBreadcrumbs,
      ),
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

    Map<String, dynamic>? asJsonMap(Object? value) {
      if (value is Map<String, dynamic>) {
        return value;
      }
      return null;
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

    final shellJson = asJsonMap(json['shellPreferences']);
    final sshJson = asJsonMap(json['sshPreferences']);
    final kubernetesJson = asJsonMap(json['kubernetesPreferences']);
    final editorJson = asJsonMap(json['editorPreferences']);
    final dockerJson = asJsonMap(json['dockerPreferences']);
    final terminalJson = asJsonMap(json['terminalPreferences']);
    final explorerJson = asJsonMap(json['explorerPreferences']);

    return AppSettings(
      themeMode: parseThemeMode(json['themeMode'] as String?),
      debugMode: json['debugMode'] as bool? ?? false,
      zoomFactor: (json['zoomFactor'] as num?)?.toDouble() ?? 1.0,
      serverAutoRefresh: json['serverAutoRefresh'] as bool? ?? true,
      serverShowOffline: json['serverShowOffline'] as bool? ?? true,
      shellPreferences: ShellPreferences(
        sidebarWidth: (shellJson?['sidebarWidth'] as num?)?.toDouble(),
        destination: shellJson?['destination'] as String?,
        sidebarCollapsed: shellJson?['sidebarCollapsed'] as bool? ?? false,
        sidebarPlacement:
            shellJson?['sidebarPlacement'] as String? ?? 'dynamic',
        useSystemDecorations:
            shellJson?['useSystemDecorations'] as bool? ?? true,
        closeToTray: shellJson?['closeToTray'] as bool? ?? false,
      ),
      appFontFamily: json['appFontFamily'] as String?,
      appThemeKey: json['appThemeKey'] as String? ?? 'blue-grey',
      uiDensity: AppUiDensityParsing.fromJson(json['uiDensity'] as String?),
      inputModePreference: InputModePreferenceParsing.fromJson(
        json['inputModePreference'] as String?,
      ),
      sshPreferences: SshPreferences(
        clientBackend: SshClientBackendParsing.fromJson(
          sshJson?['clientBackend'] as String?,
        ),
        builtinHostKeyBindings: parseBindings(
          sshJson?['builtinHostKeyBindings'] as Map<String, dynamic>?,
        ),
        customHosts:
            (sshJson?['customHosts'] as List<dynamic>?)
                ?.map((e) => CustomSshHost.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        customConfigPaths:
            (sshJson?['customConfigPaths'] as List<dynamic>?)
                ?.whereType<String>()
                .toList() ??
            const [],
        disabledConfigPaths:
            (sshJson?['disabledConfigPaths'] as List<dynamic>?)
                ?.whereType<String>()
                .toList() ??
            const [],
        disabledServerHosts:
            (sshJson?['disabledServerHosts'] as List<dynamic>?)
                ?.whereType<String>()
                .toList() ??
            const [],
      ),
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
      kubernetesPreferences: KubernetesPreferences(
        configPaths:
            (kubernetesJson?['configPaths'] as List<dynamic>?)
                ?.whereType<String>()
                .toList() ??
            const [],
        backend: KubernetesBackendParsing.fromJson(
          kubernetesJson?['backend'] as String?,
        ),
        cliCommand: kubernetesJson?['cliCommand'] as String? ?? 'kubectl',
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
      editorPreferences: EditorPreferences(
        themeLight: editorJson?['themeLight'] as String?,
        themeDark: editorJson?['themeDark'] as String?,
        fontFamily: editorJson?['fontFamily'] as String?,
        fontSize: (editorJson?['fontSize'] as num?)?.toDouble() ?? 14,
        lineHeight: (editorJson?['lineHeight'] as num?)?.toDouble() ?? 1.35,
      ),
      dockerPreferences: DockerPreferences(
        remoteHosts:
            (dockerJson?['remoteHosts'] as List<dynamic>?)
                ?.whereType<String>()
                .toList() ??
            const [],
        selectedContext: dockerJson?['selectedContext'] as String?,
        logsTail: _sanitizeTailLines(
          (dockerJson?['logsTail'] as num?)?.toInt() ?? 200,
        ),
      ),
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
      terminalPreferences: TerminalPreferences(
        fontFamily:
            terminalJson?['fontFamily'] as String? ??
            'JetBrainsMono Nerd Font',
        fontSize: (terminalJson?['fontSize'] as num?)?.toDouble() ?? 14,
        lineHeight: (terminalJson?['lineHeight'] as num?)?.toDouble() ?? 1.15,
        paddingX: (terminalJson?['paddingX'] as num?)?.toDouble() ?? 8,
        paddingY: (terminalJson?['paddingY'] as num?)?.toDouble() ?? 10,
        themeDark: terminalJson?['themeDark'] as String? ?? 'dracula',
        themeLight:
            terminalJson?['themeLight'] as String? ?? 'solarized-light',
      ),
      fileTransferUploadConcurrency: _sanitizeTransferConcurrency(
        (json['fileTransferUploadConcurrency'] as num?)?.toInt() ?? 2,
      ),
      fileTransferDownloadConcurrency: _sanitizeTransferConcurrency(
        (json['fileTransferDownloadConcurrency'] as num?)?.toInt() ?? 2,
      ),
      explorerPreferences: ExplorerPreferences(
        rowHeight: _sanitizeExplorerRowHeight(
          (explorerJson?['rowHeight'] as num?)?.toDouble() ?? 36,
        ),
        showBreadcrumbs: explorerJson?['showBreadcrumbs'] as bool? ?? true,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    final shell = shellPreferences;
    final editor = editorPreferences;
    final docker = dockerPreferences;
    final terminal = terminalPreferences;
    final explorer = explorerPreferences;
    return {
      'themeMode': themeMode.name,
      'debugMode': debugMode,
      'zoomFactor': zoomFactor,
      'serverAutoRefresh': serverAutoRefresh,
      'serverShowOffline': serverShowOffline,
      'shellPreferences': {
        'sidebarWidth': shell.sidebarWidth,
        'destination': shell.destination,
        'sidebarCollapsed': shell.sidebarCollapsed,
        'sidebarPlacement': shell.sidebarPlacement,
        'useSystemDecorations': shell.useSystemDecorations,
        'closeToTray': shell.closeToTray,
      },
      if (appFontFamily != null) 'appFontFamily': appFontFamily,
      'appThemeKey': appThemeKey,
      'uiDensity': uiDensity.name,
      'inputModePreference': inputModePreference.name,
      'sshPreferences': {
        'clientBackend': sshPreferences.clientBackend.name,
        'builtinHostKeyBindings': sshPreferences.builtinHostKeyBindings,
        'customHosts': sshPreferences.customHosts.map((h) => h.toJson()).toList(),
        'customConfigPaths': sshPreferences.customConfigPaths,
        'disabledConfigPaths': sshPreferences.disabledConfigPaths,
        'disabledServerHosts': sshPreferences.disabledServerHosts,
      },
      'kubernetesPreferences': {
        'configPaths': kubernetesPreferences.configPaths,
        'backend': kubernetesPreferences.backend.name,
        'cliCommand': kubernetesPreferences.cliCommand,
      },
      'shortcutBindings': shortcutBindings,
      'editorPreferences': {
        if (editor.themeLight != null) 'themeLight': editor.themeLight,
        if (editor.themeDark != null) 'themeDark': editor.themeDark,
        if (editor.fontFamily != null) 'fontFamily': editor.fontFamily,
        'fontSize': editor.fontSize,
        'lineHeight': editor.lineHeight,
      },
      'dockerPreferences': {
        'remoteHosts': docker.remoteHosts,
        if (docker.selectedContext != null)
          'selectedContext': docker.selectedContext,
        'logsTail': dockerLogsTailClamped,
      },
      'terminalPreferences': {
        if (terminal.fontFamily != null) 'fontFamily': terminal.fontFamily,
        'fontSize': terminal.fontSize,
        'lineHeight': terminal.lineHeight,
        'paddingX': terminal.paddingX,
        'paddingY': terminal.paddingY,
        'themeDark': terminal.themeDark,
        'themeLight': terminal.themeLight,
      },
      'fileTransferUploadConcurrency': fileTransferUploadConcurrency,
      'fileTransferDownloadConcurrency': fileTransferDownloadConcurrency,
      'explorerPreferences': {
        'rowHeight': explorer.rowHeight,
        'showBreadcrumbs': explorer.showBreadcrumbs,
      },
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
