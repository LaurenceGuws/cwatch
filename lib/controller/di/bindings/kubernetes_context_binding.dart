import 'package:flutter/widgets.dart';

import 'package:cwatch/controller/controllers/kubernetes_context_controller.dart';
import 'package:cwatch/controller/di/bindings/settings_binding.dart';
import 'package:cwatch/model/services_infra/kubernetes/kubeconfig_service.dart';
import 'package:cwatch/model/services_infra/settings/app_settings_controller.dart';
import 'package:cwatch/model/services_infra/settings/workspace_root_controller.dart';
import 'package:cwatch/model/services_infra/ssh/builtin/builtin_ssh_key_service.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/controller/core/workspace/workspace_tab.dart';
import 'package:cwatch/view/features/kubernetes/kubernetes_runtime.dart';
import 'package:cwatch/view/features/kubernetes/kubernetes_tab_builder.dart';
import 'package:cwatch/view/features/kubernetes/kubernetes_workspace_controller.dart';
import 'package:cwatch/controller/adapters/kubernetes_ui_adapter.dart';

class KubernetesContextBinding {
  const KubernetesContextBinding();

  KubernetesContextController create({KubeconfigService? kubeconfig}) {
    return KubernetesContextController(kubeconfig: kubeconfig);
  }

  KubernetesRuntime createRuntime({
    required BuildContext context,
    required AppSettingsController appSettingsController,
    required BuiltInSshKeyService keyService,
    required Future<List<SshHost>> hostsFuture,
    required WorkspaceTab Function() baseTabBuilder,
    KubeconfigService? kubeconfig,
  }) {
    final workspaceRootController = WorkspaceRootController(
      settingsController: appSettingsController,
    );
    final contextController = create(kubeconfig: kubeconfig);
    final uiAdapter = KubernetesUiAdapter(context: context);
    final settingsController = const SettingsBinding().createController(
      settingsController: appSettingsController,
      keyService: keyService,
      hostsFuture: hostsFuture,
      uiAdapter: const SettingsBinding().createUiAdapter(context: context),
    );
    final tabBuilder = const KubernetesTabBuilder(
      placeholderName: '__k8s_placeholder__',
      placeholderConfig: '__k8s_placeholder__',
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
}
