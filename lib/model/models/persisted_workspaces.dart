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
}
