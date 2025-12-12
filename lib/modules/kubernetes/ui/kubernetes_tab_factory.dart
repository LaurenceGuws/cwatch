import 'package:flutter/material.dart';

import 'package:cwatch/core/models/tab_state.dart';
import 'package:cwatch/models/kubernetes_workspace_state.dart';
import 'package:cwatch/shared/views/shared/tabs/tab_chip.dart';
import 'package:cwatch/services/kubernetes/kubeconfig_service.dart';

import 'kubernetes_tab.dart';

class KubernetesTabFactory {
  const KubernetesTabFactory({
    required this.placeholderName,
    required this.placeholderConfig,
    required this.buildPlaceholder,
    required this.buildDetails,
    required this.buildResources,
    required this.detailsIcon,
    required this.resourcesIcon,
  });

  final String placeholderName;
  final String placeholderConfig;
  final Widget Function() buildPlaceholder;
  final Widget Function(KubeconfigContext context) buildDetails;
  final Widget Function(KubeconfigContext context, TabOptionsController options)
  buildResources;
  final IconData detailsIcon;
  final IconData resourcesIcon;

  KubernetesTab placeholder({String? id}) {
    final tabId = id ?? _uniqueId();
    return KubernetesTab(
      id: tabId,
      kind: KubernetesTabKind.details,
      canDrag: false,
      closable: true,
      body: buildPlaceholder(),
      optionsController: TabOptionsController(),
      workspaceState: TabState(
        id: tabId,
        kind: 'placeholder',
        contextName: placeholderName,
        path: placeholderConfig,
        title: 'Kubernetes',
        label: 'Kubernetes',
      ),
    );
  }

  KubernetesTab contextTab({
    required String id,
    required KubeconfigContext context,
    KubernetesTabKind kind = KubernetesTabKind.details,
    String? customName,
    TabOptionsController? optionsController,
  }) {
    final controller =
        optionsController ??
        (kind == KubernetesTabKind.resources
            ? CompositeTabOptionsController()
            : TabOptionsController());
    final body = kind == KubernetesTabKind.resources
        ? buildResources(context, controller)
        : buildDetails(context);
    return KubernetesTab(
      id: id,
      kind: kind,
      context: context,
      customName: customName,
      canDrag: true,
      closable: true,
      body: body,
      optionsController: controller,
      workspaceState: TabState(
        id: id,
        kind: kind.name,
        contextName: context.name,
        path: context.configPath,
        title: customName ?? context.name,
        label: customName ?? context.name,
      ),
    );
  }

  String _uniqueId() => DateTime.now().microsecondsSinceEpoch.toString();
}
