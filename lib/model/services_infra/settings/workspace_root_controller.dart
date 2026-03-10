import 'package:cwatch/model/models/persisted_workspaces.dart';

import 'app_settings_controller.dart';
import 'workspace_storage.dart';

class WorkspaceRootController {
  WorkspaceRootController({
    required AppSettingsController settingsController,
    WorkspaceStorage? storage,
  }) : _settingsController = settingsController,
       _storage = storage ?? WorkspaceStorage(),
       _workspaces = PersistedWorkspaces.fromAppSettings(
         settingsController.settings,
       );

  final AppSettingsController _settingsController;
  final WorkspaceStorage _storage;
  PersistedWorkspaces _workspaces;
  bool _loaded = false;
  Future<void>? _loadFuture;

  PersistedWorkspaces get workspaces => _workspaces;

  bool get isLoaded => _loaded;

  Future<PersistedWorkspaces> ensureLoaded() async {
    if (_loaded) {
      return _workspaces;
    }

    final pending = _loadFuture;
    if (pending != null) {
      await pending;
      return _workspaces;
    }

    final future = _load();
    _loadFuture = future;
    await future;
    _loadFuture = null;
    _loaded = true;
    return _workspaces;
  }

  Future<void> update(
    PersistedWorkspaces Function(PersistedWorkspaces current) transform,
  ) async {
    await ensureLoaded();
    _workspaces = transform(_workspaces);
    await _storage.save(_workspaces);
  }

  Future<void> _load() async {
    _workspaces = await _storage.load(
      fallback: PersistedWorkspaces.fromAppSettings(_settingsController.settings),
    );
  }
}
