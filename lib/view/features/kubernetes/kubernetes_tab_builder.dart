import 'package:flutter/material.dart';

import 'package:cwatch/model/core/models/tab_state.dart';
import 'package:cwatch/controller/core/workspace/workspace_tab.dart';
import 'package:cwatch/model/models/kubernetes_workspace_state.dart';
import 'package:cwatch/model/models/kubernetes/kubeconfig_context.dart';
import 'package:cwatch/model/shared/theme/nerd_fonts.dart';
import 'package:cwatch/controller/core/workspace/tab_options.dart';

class KubernetesTabBuilder {
  const KubernetesTabBuilder({
    required this.placeholderName,
    required this.placeholderConfig,
  });

  final String placeholderName;
  final String placeholderConfig;

  WorkspaceTab placeholder({required String id, required Widget body}) {
    final controller = TabOptionsController();
    return WorkspaceTab(
      id: id,
      title: 'Kubernetes Contexts',
      label: 'Contexts',
      icon: Icons.view_list_rounded,
      body: body,
      canDrag: false,
      canRename: false,
      isPicker: true,
      workspaceState: KubernetesTabData(
        kind: KubernetesTabKind.details,
        context: null,
        persistedState: TabState(
          id: id,
          kind: 'placeholder',
          contextName: placeholderName,
          path: placeholderConfig,
          title: 'Kubernetes Contexts',
          label: 'Contexts',
        ),
      ),
      optionsController: controller,
    );
  }

  WorkspaceTab details({
    required String id,
    required KubeconfigContext context,
    required Widget body,
    String? customName,
    TabOptionsController? optionsController,
  }) {
    final controller = optionsController ?? TabOptionsController();
    final title = (customName != null && customName.trim().isNotEmpty)
        ? customName.trim()
        : context.name;
    return WorkspaceTab(
      id: id,
      title: title,
      label: title,
      icon: NerdIcon.kubernetes.data,
      body: body,
      canDrag: true,
      canRename: true,
      workspaceState: KubernetesTabData(
        kind: KubernetesTabKind.details,
        context: context,
        customName: customName,
        persistedState: TabState(
          id: id,
          kind: KubernetesTabKind.details.name,
          contextName: context.name,
          path: context.configPath,
          title: title,
          label: title,
        ),
      ),
      optionsController: controller,
    );
  }
}

class KubernetesTabData {
  const KubernetesTabData({
    required this.kind,
    required this.context,
    required this.persistedState,
    this.customName,
  });

  final KubernetesTabKind kind;
  final KubeconfigContext? context;
  final TabState persistedState;
  final String? customName;
}
