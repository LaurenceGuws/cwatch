import 'package:cwatch/model/models/app_settings.dart';
import 'package:cwatch/model/models/persisted_workspaces.dart';

import 'app_settings_controller.dart';

class WorkspaceRootController {
  WorkspaceRootController({required AppSettingsController settingsController})
    : _settingsController = settingsController;

  final AppSettingsController _settingsController;

  PersistedWorkspaces get workspaces =>
      PersistedWorkspaces.fromAppSettings(_settingsController.settings);

  bool get isLoaded => _settingsController.isLoaded;

  Future<void> update(
    PersistedWorkspaces Function(PersistedWorkspaces current) transform,
  ) async {
    await _settingsController.update((current) {
      final next = transform(PersistedWorkspaces.fromAppSettings(current));
      return _writeToSettings(current, next);
    });
  }

  AppSettings _writeToSettings(
    AppSettings current,
    PersistedWorkspaces workspaces,
  ) {
    return current.copyWith(
      serverWorkspace: workspaces.server,
      dockerWorkspace: workspaces.docker,
      kubernetesWorkspace: workspaces.kubernetes,
      wslWorkspace: workspaces.wsl,
    );
  }
}
