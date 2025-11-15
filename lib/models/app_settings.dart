import 'package:flutter/material.dart';

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
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      telemetryEnabled: telemetryEnabled ?? this.telemetryEnabled,
      mfaRequired: mfaRequired ?? this.mfaRequired,
      sshRotationEnabled: sshRotationEnabled ?? this.sshRotationEnabled,
      auditStreamingEnabled: auditStreamingEnabled ?? this.auditStreamingEnabled,
      autoUpdateAgents: autoUpdateAgents ?? this.autoUpdateAgents,
      agentAlertsEnabled: agentAlertsEnabled ?? this.agentAlertsEnabled,
      zoomFactor: zoomFactor ?? this.zoomFactor,
      serverAutoRefresh: serverAutoRefresh ?? this.serverAutoRefresh,
      serverShowOffline: serverShowOffline ?? this.serverShowOffline,
      dockerLiveStats: dockerLiveStats ?? this.dockerLiveStats,
      dockerPruneWarnings: dockerPruneWarnings ?? this.dockerPruneWarnings,
      kubernetesAutoDiscover: kubernetesAutoDiscover ?? this.kubernetesAutoDiscover,
      kubernetesIncludeSystemPods: kubernetesIncludeSystemPods ?? this.kubernetesIncludeSystemPods,
    );
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
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
      kubernetesIncludeSystemPods: json['kubernetesIncludeSystemPods'] as bool? ?? false,
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
    };
  }
}
