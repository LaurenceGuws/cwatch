import 'package:cwatch/controller/adapters/kubernetes_ui_adapter.dart';
import 'package:cwatch/controller/controllers/kubernetes_context_controller.dart';
import 'package:cwatch/controller/controllers/settings_controller.dart';

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

  void dispose() {
    settingsController.dispose();
    workspaceController.dispose();
  }
}
