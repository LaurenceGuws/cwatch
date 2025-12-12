import 'package:flutter/widgets.dart';

import '../../core/navigation/shell_module.dart';
import 'package:cwatch/services/settings/app_settings_controller.dart';
import '../../shared/theme/nerd_fonts.dart';
import 'ui/kubernetes_context_list.dart';

class KubernetesModule extends ShellModuleView {
  KubernetesModule({required this.settingsController});

  final AppSettingsController settingsController;

  @override
  String get id => 'kubernetes';

  @override
  String get label => 'Kubernetes';

  @override
  NerdIcon get icon => NerdIcon.kubernetes;

  @override
  Widget build(BuildContext context, Widget leading) {
    return KubernetesContextList(
      moduleId: id,
      leading: leading,
      settingsController: settingsController,
    );
  }
}
