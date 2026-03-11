import 'package:flutter/widgets.dart';

import 'package:cwatch/controller/adapters/kubernetes_ui_adapter.dart';
import 'package:cwatch/controller/controllers/kubernetes_context_controller.dart';
import 'package:cwatch/controller/controllers/settings_controller.dart';
import 'package:cwatch/controller/core/workspace/workspace_tab.dart';
import 'package:cwatch/controller/di/bindings/settings_binding.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/services_infra/kubernetes/kubeconfig_service.dart';
import 'package:cwatch/model/services_infra/settings/app_settings_controller.dart';
import 'package:cwatch/model/services_infra/settings/workspace_root_controller.dart';
import 'package:cwatch/model/services_infra/ssh/builtin/builtin_ssh_key_service.dart';

import 'kubernetes_tab_builder.dart';
import 'kubernetes_workspace_controller.dart';

class KubernetesRuntime {
  const KubernetesRuntime({
    required this.contextController,
    required this.settingsController,
    required this.tabBuilder,
    required this.workspaceController,
    required this.uiAdapter,
  });

  final KubernetesContextController contextController;
  final SettingsController settingsController;
  final KubernetesTabBuilder tabBuilder;
  final KubernetesWorkspaceController workspaceController;
  final KubernetesUiAdapter uiAdapter;

  static KubernetesContextController createContextController({
    KubeconfigService? kubeconfig,
  }) {
    return KubernetesContextController(kubeconfig: kubeconfig);
  }

  static KubernetesRuntime create({
    required BuildContext context,
    required AppSettingsController appSettingsController,
    required BuiltInSshKeyService keyService,
    required Future<List<SshHost>> hostsFuture,
    required KubernetesTabBuilder tabBuilder,
    required WorkspaceTab Function() baseTabBuilder,
    KubeconfigService? kubeconfig,
  }) {
    final workspaceRootController = WorkspaceRootController(
      settingsController: appSettingsController,
    );
    final contextController = createContextController(kubeconfig: kubeconfig);
    final uiAdapter = KubernetesUiAdapter(context: context);
    final settingsController = const SettingsBinding().createController(
      settingsController: appSettingsController,
      keyService: keyService,
      hostsFuture: hostsFuture,
      uiAdapter: const SettingsBinding().createUiAdapter(context: context),
    );
    final workspaceController = KubernetesWorkspaceController(
      settingsController: appSettingsController,
      workspaceRootController: workspaceRootController,
      baseTabBuilder: baseTabBuilder,
    );
    return KubernetesRuntime(
      contextController: contextController,
      settingsController: settingsController,
      tabBuilder: tabBuilder,
      workspaceController: workspaceController,
      uiAdapter: uiAdapter,
    );
  }

  void dispose() {
    settingsController.dispose();
    workspaceController.dispose();
  }
}
