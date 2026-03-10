import 'package:flutter/material.dart';

import 'package:cwatch/controller/core/workspace/workspace_tab.dart';
import 'package:cwatch/model/models/explorer_context.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/models/docker_workspace_state.dart';
import 'package:cwatch/model/services_infra/ssh/remote_shell_service.dart';

abstract class DockerOverviewTabFactory {
  WorkspaceTab commandTerminal({
    required String id,
    required String title,
    required String label,
    required String command,
    required IconData icon,
    required SshHost? host,
    required RemoteShellService? shellService,
    VoidCallback? onExit,
    DockerTabKind kind = DockerTabKind.command,
    String? containerId,
    String? containerName,
    String? contextName,
    Future<void> Function(String path, String content)? onOpenEditorTab,
  });

  WorkspaceTab composeLogs({
    required String id,
    required String title,
    required String label,
    required IconData icon,
    required String composeBase,
    required String project,
    required List<String> services,
    required SshHost? host,
    required RemoteShellService? shellService,
    String? contextName,
    VoidCallback? onExit,
    required int tailLines,
    Future<void> Function(String path, String content)? onOpenEditorTab,
  });

  WorkspaceTab explorer({
    required String id,
    required String title,
    required String label,
    required IconData icon,
    required SshHost host,
    required RemoteShellService shellService,
    required ExplorerContext explorerContext,
    required String containerId,
    String? containerName,
    String? dockerContextName,
    required void Function(WorkspaceTab tab) onOpenTab,
    String? initialPath,
    void Function(String path)? onPathChanged,
  });
}
