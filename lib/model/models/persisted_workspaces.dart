import 'package:cwatch/model/models/app_settings.dart';
import 'package:cwatch/model/models/docker_workspace_state.dart';
import 'package:cwatch/model/models/kubernetes_workspace_state.dart';
import 'package:cwatch/model/models/server_workspace_state.dart';
import 'package:cwatch/model/models/wsl_workspace_state.dart';

class PersistedWorkspaces {
  const PersistedWorkspaces({
    this.server,
    this.docker,
    this.kubernetes,
    this.wsl,
  });

  final ServerWorkspaceState? server;
  final DockerWorkspaceState? docker;
  final KubernetesWorkspaceState? kubernetes;
  final WslWorkspaceState? wsl;

  factory PersistedWorkspaces.fromAppSettings(AppSettings settings) {
    return PersistedWorkspaces(
      server: settings.serverWorkspace,
      docker: settings.dockerWorkspace,
      kubernetes: settings.kubernetesWorkspace,
      wsl: settings.wslWorkspace,
    );
  }

  factory PersistedWorkspaces.fromJson(Map<String, dynamic> json) {
    ServerWorkspaceState? parseServer(dynamic raw) {
      if (raw is Map<String, dynamic>) {
        return ServerWorkspaceState.fromJson(raw);
      }
      return null;
    }

    KubernetesWorkspaceState? parseKubernetes(dynamic raw) {
      if (raw is Map<String, dynamic>) {
        return KubernetesWorkspaceState.fromJson(raw);
      }
      return null;
    }

    WslWorkspaceState? parseWsl(dynamic raw) {
      if (raw is Map<String, dynamic>) {
        return WslWorkspaceState.fromJson(raw);
      }
      return null;
    }

    DockerWorkspaceState? parseDocker(dynamic raw) {
      if (raw is Map<String, dynamic>) {
        return DockerWorkspaceState.fromJson(raw);
      }
      return null;
    }

    return PersistedWorkspaces(
      server: parseServer(json['server']),
      docker: parseDocker(json['docker']),
      kubernetes: parseKubernetes(json['kubernetes']),
      wsl: parseWsl(json['wsl']),
    );
  }

  PersistedWorkspaces copyWith({
    ServerWorkspaceState? server,
    DockerWorkspaceState? docker,
    KubernetesWorkspaceState? kubernetes,
    WslWorkspaceState? wsl,
  }) {
    return PersistedWorkspaces(
      server: server ?? this.server,
      docker: docker ?? this.docker,
      kubernetes: kubernetes ?? this.kubernetes,
      wsl: wsl ?? this.wsl,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (server != null) 'server': server!.toJson(),
      if (docker != null) 'docker': docker!.toJson(),
      if (kubernetes != null) 'kubernetes': kubernetes!.toJson(),
      if (wsl != null) 'wsl': wsl!.toJson(),
    };
  }
}
