import 'package:flutter/widgets.dart';

import 'package:cwatch/controller/controllers/docker_shell_callbacks.dart';
import 'package:cwatch/controller/core/workspace/workspace_tab.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/view/features/docker/docker_tab_builder.dart';

enum DockerDashboardTarget { overview, resources }

class DockerViewDashboardHelper {
  const DockerViewDashboardHelper();

  WorkspaceTab buildContextDashboardTab({
    required String contextName,
    required DockerDashboardTarget target,
    required IconData icon,
    required DockerTabBuilder tabBuilder,
    required void Function(WorkspaceTab tab) onOpenTab,
    required void Function(String id) onCloseTab,
    String? id,
  }) {
    final tabId =
        id ?? 'ctx-$contextName-${DateTime.now().microsecondsSinceEpoch}';
    switch (target) {
      case DockerDashboardTarget.resources:
        return tabBuilder.resources(
          id: tabId,
          title: contextName,
          label: contextName,
          icon: icon,
          contextName: contextName,
          onOpenTab: onOpenTab,
          onCloseTab: onCloseTab,
        );
      case DockerDashboardTarget.overview:
        return tabBuilder.overview(
          id: tabId,
          title: contextName,
          label: contextName,
          icon: icon,
          contextName: contextName,
          onOpenTab: onOpenTab,
          onCloseTab: onCloseTab,
        );
    }
  }

  WorkspaceTab buildHostDashboardTab({
    required SshHost host,
    required DockerDashboardTarget target,
    required IconData icon,
    required DockerShellCallbacks shellCallbacks,
    required DockerTabBuilder tabBuilder,
    required void Function(WorkspaceTab tab) onOpenTab,
    required void Function(String id) onCloseTab,
    String? id,
  }) {
    final shell = shellCallbacks.shellForHost(host);
    final tabId =
        id ?? 'host-${host.name}-${DateTime.now().microsecondsSinceEpoch}';
    switch (target) {
      case DockerDashboardTarget.resources:
        return tabBuilder.resources(
          id: tabId,
          title: host.name,
          label: host.name,
          icon: icon,
          remoteHost: host,
          shellService: shell,
          onOpenTab: onOpenTab,
          onCloseTab: onCloseTab,
        );
      case DockerDashboardTarget.overview:
        return tabBuilder.overview(
          id: tabId,
          title: host.name,
          label: host.name,
          icon: icon,
          remoteHost: host,
          shellService: shell,
          onOpenTab: onOpenTab,
          onCloseTab: onCloseTab,
        );
    }
  }
}
