import 'package:flutter/widgets.dart';

import 'package:cwatch/model/services_infra/settings/app_settings_controller.dart';
import 'package:cwatch/model/services_infra/zide/zide_ffi_smoke_service.dart';
import 'package:cwatch/model/shared/theme/nerd_fonts.dart';
import 'package:cwatch/view/core/navigation/shell_module.dart';
import 'package:cwatch/view/features/migration/migration_view.dart';

class MigrationModule extends ShellModuleView {
  MigrationModule({
    required this.settingsController,
    required this.zideFfiSmokeService,
  });

  final AppSettingsController settingsController;
  final ZideFfiSmokeService zideFfiSmokeService;

  @override
  String get id => 'migration';

  @override
  String get label => 'Migration';

  @override
  NerdIcon get icon => NerdIcon.config;

  @override
  bool get isPrimary => false;

  @override
  Widget build(BuildContext context, Widget leading) {
    return MigrationView(
      settingsController: settingsController,
      zideFfiSmokeService: zideFfiSmokeService,
      leading: leading,
    );
  }
}
