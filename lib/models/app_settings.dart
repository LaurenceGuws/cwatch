import 'package:flutter/material.dart';

import 'ssh_client_backend.dart';

class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.notificationsEnabled = true,
    this.telemetryEnabled = false,
    this.mfaRequired = true,
    this.sshRotationEnabled = true,
    this.auditStreamingEnabled = false,
    this.autoUpdateAgents = true,
    this.agentAlertsEnabled = true,
    this.zoomFactor = 1.0,
    this.serverAutoRefresh = true,
    this.serverShowOffline = true,
    this.dockerLiveStats = true,
    this.dockerPruneWarnings = false,
    this.kubernetesAutoDiscover = true,
    this.kubernetesIncludeSystemPods = false,
    this.shellSidebarWidth,
    this.shellDestination,
    this.shellSidebarCollapsed = false,
    this.sshClientBackend = SshClientBackend.platform,
    this.builtinSshHostKeyBindings = const {},
  });

  final ThemeMode themeMode;
  final bool notificationsEnabled;
  final bool telemetryEnabled;
  final bool mfaRequired;
  final bool sshRotationEnabled;
  final bool auditStreamingEnabled;
  final bool autoUpdateAgents;
  final bool agentAlertsEnabled;
  final double zoomFactor;
  final bool serverAutoRefresh;
  final bool serverShowOffline;
  final bool dockerLiveStats;
  final bool dockerPruneWarnings;
  final bool kubernetesAutoDiscover;
  final bool kubernetesIncludeSystemPods;
  final double? shellSidebarWidth;
  final String? shellDestination;
  final bool shellSidebarCollapsed;
  final SshClientBackend sshClientBackend;
  final Map<String, String> builtinSshHostKeyBindings;

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? notificationsEnabled,
    bool? telemetryEnabled,
    bool? mfaRequired,
    bool? sshRotationEnabled,
    bool? auditStreamingEnabled,
    bool? autoUpdateAgents,
    bool? agentAlertsEnabled,
    double? zoomFactor,
    bool? serverAutoRefresh,
    bool? serverShowOffline,
    bool? dockerLiveStats,
    bool? dockerPruneWarnings,
    bool? kubernetesAutoDiscover,
    bool? kubernetesIncludeSystemPods,
    double? shellSidebarWidth,
    String? shellDestination,
    bool? shellSidebarCollapsed,
    SshClientBackend? sshClientBackend,
    Map<String, String>? builtinSshHostKeyBindings,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      telemetryEnabled: telemetryEnabled ?? this.telemetryEnabled,
      mfaRequired: mfaRequired ?? this.mfaRequired,
      sshRotationEnabled: sshRotationEnabled ?? this.sshRotationEnabled,
      auditStreamingEnabled:
          auditStreamingEnabled ?? this.auditStreamingEnabled,
      autoUpdateAgents: autoUpdateAgents ?? this.autoUpdateAgents,
      agentAlertsEnabled: agentAlertsEnabled ?? this.agentAlertsEnabled,
      zoomFactor: zoomFactor ?? this.zoomFactor,
      serverAutoRefresh: serverAutoRefresh ?? this.serverAutoRefresh,
      serverShowOffline: serverShowOffline ?? this.serverShowOffline,
      dockerLiveStats: dockerLiveStats ?? this.dockerLiveStats,
      dockerPruneWarnings: dockerPruneWarnings ?? this.dockerPruneWarnings,
      kubernetesAutoDiscover:
          kubernetesAutoDiscover ?? this.kubernetesAutoDiscover,
      kubernetesIncludeSystemPods:
          kubernetesIncludeSystemPods ?? this.kubernetesIncludeSystemPods,
      shellSidebarWidth: shellSidebarWidth ?? this.shellSidebarWidth,
      shellDestination: shellDestination ?? this.shellDestination,
      shellSidebarCollapsed:
          shellSidebarCollapsed ?? this.shellSidebarCollapsed,
      sshClientBackend: sshClientBackend ?? this.sshClientBackend,
      builtinSshHostKeyBindings:
          builtinSshHostKeyBindings ?? this.builtinSshHostKeyBindings,
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
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
      telemetryEnabled: json['telemetryEnabled'] as bool? ?? false,
      mfaRequired: json['mfaRequired'] as bool? ?? true,
      sshRotationEnabled: json['sshRotationEnabled'] as bool? ?? true,
      auditStreamingEnabled: json['auditStreamingEnabled'] as bool? ?? false,
      autoUpdateAgents: json['autoUpdateAgents'] as bool? ?? true,
      agentAlertsEnabled: json['agentAlertsEnabled'] as bool? ?? true,
      zoomFactor: (json['zoomFactor'] as num?)?.toDouble() ?? 1.0,
      serverAutoRefresh: json['serverAutoRefresh'] as bool? ?? true,
      serverShowOffline: json['serverShowOffline'] as bool? ?? true,
      dockerLiveStats: json['dockerLiveStats'] as bool? ?? true,
      dockerPruneWarnings: json['dockerPruneWarnings'] as bool? ?? false,
      kubernetesAutoDiscover: json['kubernetesAutoDiscover'] as bool? ?? true,
      kubernetesIncludeSystemPods:
          json['kubernetesIncludeSystemPods'] as bool? ?? false,
      shellSidebarWidth: (json['shellSidebarWidth'] as num?)?.toDouble(),
      shellDestination: json['shellDestination'] as String?,
      shellSidebarCollapsed: json['shellSidebarCollapsed'] as bool? ?? false,
      sshClientBackend: SshClientBackendParsing.fromJson(
        json['sshClientBackend'] as String?,
      ),
      builtinSshHostKeyBindings: parseBindings(
        json['builtinSshHostKeyBindings'] as Map<String, dynamic>?,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'themeMode': themeMode.name,
      'notificationsEnabled': notificationsEnabled,
      'telemetryEnabled': telemetryEnabled,
      'mfaRequired': mfaRequired,
      'sshRotationEnabled': sshRotationEnabled,
      'auditStreamingEnabled': auditStreamingEnabled,
      'autoUpdateAgents': autoUpdateAgents,
      'agentAlertsEnabled': agentAlertsEnabled,
      'zoomFactor': zoomFactor,
      'serverAutoRefresh': serverAutoRefresh,
      'serverShowOffline': serverShowOffline,
      'dockerLiveStats': dockerLiveStats,
      'dockerPruneWarnings': dockerPruneWarnings,
      'kubernetesAutoDiscover': kubernetesAutoDiscover,
      'kubernetesIncludeSystemPods': kubernetesIncludeSystemPods,
      'shellSidebarWidth': shellSidebarWidth,
      'shellDestination': shellDestination,
      'shellSidebarCollapsed': shellSidebarCollapsed,
      'sshClientBackend': sshClientBackend.name,
      'builtinSshHostKeyBindings': builtinSshHostKeyBindings,
    };
  }
}
