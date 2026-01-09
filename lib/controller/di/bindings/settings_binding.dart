import 'package:flutter/material.dart';

import 'package:cwatch/controller/adapters/settings_ui_adapter.dart';
import 'package:cwatch/controller/controllers/settings_controller.dart';
import 'package:cwatch/controller/repositories/settings_repository.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/services_infra/settings/app_settings_controller.dart';
import 'package:cwatch/model/services_infra/ssh/builtin/builtin_ssh_key_service.dart';

class SettingsBinding {
  const SettingsBinding();

  SettingsUiAdapter createUiAdapter({required BuildContext context}) {
    return SettingsUiAdapter(context: context);
  }

  SettingsController createController({
    required AppSettingsController settingsController,
    required BuiltInSshKeyService keyService,
    required Future<List<SshHost>> hostsFuture,
    required SettingsUiAdapter uiAdapter,
    SettingsRepository? repository,
  }) {
    return SettingsController(
      settingsController: settingsController,
      keyService: keyService,
      hostsFuture: hostsFuture,
      uiAdapter: uiAdapter,
      repository: repository,
    );
  }
}
