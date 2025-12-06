import 'package:flutter/material.dart';

import 'package:cwatch/core/models/tab_state.dart';
import 'package:cwatch/models/ssh_host.dart';
import 'package:cwatch/models/kubernetes_workspace_state.dart';
import 'package:cwatch/services/kubernetes/kubeconfig_service.dart';
import 'package:cwatch/shared/theme/nerd_fonts.dart';
import 'package:cwatch/shared/views/shared/tabs/tab_chip.dart';

class KubernetesTab {
  KubernetesTab({
    required this.id,
    required this.kind,
    required this.body,
    this.context,
    this.customName,
    this.workspaceState,
    this.optionsController,
    this.closable = true,
    this.canDrag = true,
  });

  final String id;
  final KubernetesTabKind kind;
  final Widget body;
  final KubeconfigContext? context;
  final String? customName;
  final TabState? workspaceState;
  final TabOptionsController? optionsController;
  final bool closable;
  final bool canDrag;

  String get title {
    if (customName != null && customName!.trim().isNotEmpty) {
      return customName!.trim();
    }
    if (context != null) {
      return context!.name;
    }
    return 'Kubernetes';
  }

  String get label => title;

  IconData get icon {
    if (kind == KubernetesTabKind.resources) {
      return NerdIcon.database.data;
    }
    return NerdIcon.kubernetes.data;
  }

  bool get canRename => context != null;

  SshHost get host => SshHost(
    name: label,
    hostname: context?.server ?? '',
    port: 0,
    available: true,
  );

  KubernetesTab copyWith({
    String? id,
    KubernetesTabKind? kind,
    Widget? body,
    KubeconfigContext? context,
    String? customName,
    bool setCustomName = false,
    TabState? workspaceState,
    TabOptionsController? optionsController,
    bool? closable,
    bool? canDrag,
  }) {
    return KubernetesTab(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      body: body ?? this.body,
      context: context ?? this.context,
      customName: setCustomName ? customName : this.customName,
      workspaceState: workspaceState ?? this.workspaceState,
      optionsController: optionsController ?? this.optionsController,
      closable: closable ?? this.closable,
      canDrag: canDrag ?? this.canDrag,
    );
  }
}
