import 'package:flutter/widgets.dart';

import 'package:cwatch/view/core/navigation/shell_module.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/services_infra/settings/app_settings_controller.dart';
import 'package:cwatch/model/services_infra/ssh/builtin/builtin_ssh_key_service.dart';
import 'package:cwatch/model/shared/theme/nerd_fonts.dart';
import 'package:cwatch/view/features/kubernetes/kubernetes_context_list.dart';

class KubernetesModule extends ShellModuleView {
  KubernetesModule({
    required this.settingsController,
    required this.keyService,
    required this.hostsFuture,
  });

  final AppSettingsController settingsController;
  final BuiltInSshKeyService keyService;
  final Future<List<SshHost>> hostsFuture;

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
      keyService: keyService,
      hostsFuture: hostsFuture,
    );
  }
}
