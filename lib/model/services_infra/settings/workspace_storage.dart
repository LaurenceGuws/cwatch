import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:cwatch/model/models/persisted_workspaces.dart';

import '../logging/app_logger.dart';
import 'settings_path_provider.dart';

class WorkspaceStorage {
  WorkspaceStorage({SettingsPathProvider? pathProvider})
    : _pathProvider = pathProvider ?? const SettingsPathProvider();

  final SettingsPathProvider _pathProvider;

  Future<PersistedWorkspaces> load({
    PersistedWorkspaces fallback = const PersistedWorkspaces(),
  }) async {
    final file = await _workspaceFile();
    if (!await file.exists()) {
      await save(fallback);
      return fallback;
    }

    try {
      final contents = await file.readAsString();
      final dynamic jsonMap = jsonDecode(contents);
      if (jsonMap is Map<String, dynamic>) {
        return PersistedWorkspaces.fromJson(jsonMap);
      }
    } catch (error, stackTrace) {
      AppLogger().warn(
        'Failed to load persisted workspaces; falling back',
        tag: 'Settings',
        error: error,
        stackTrace: stackTrace,
      );
    }

    return fallback;
  }

  Future<void> save(PersistedWorkspaces workspaces) async {
    final file = await _workspaceFile();
    final encoded = await Isolate.run(() => jsonEncode(workspaces.toJson()));
    await file.writeAsString(encoded);
  }

  Future<File> _workspaceFile() async {
    final directory = await _pathProvider.configDirectory();
    final file = File('$directory/workspaces.json');
    await file.parent.create(recursive: true);
    return file;
  }
}
