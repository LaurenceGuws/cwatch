import 'dart:convert';
import 'dart:io';

import '../../models/app_settings.dart';
import '../logging/app_logger.dart';
import 'settings_path_provider.dart';

class SettingsStorage {
  SettingsStorage({SettingsPathProvider? pathProvider})
    : _pathProvider = pathProvider ?? const SettingsPathProvider();

  final SettingsPathProvider _pathProvider;

  Future<AppSettings> load() async {
    final file = await _settingsFile();
    final migrated = await _maybeMigrateLegacyFile(file);
    if (!migrated && !await file.exists()) {
      final defaults = const AppSettings();
      await save(defaults);
      return defaults;
    }
    try {
      final contents = await file.readAsString();
      final dynamic jsonMap = jsonDecode(contents);
      if (jsonMap is Map<String, dynamic>) {
        return AppSettings.fromJson(jsonMap);
      }
    } catch (error, stackTrace) {
      AppLogger.w(
        'Failed to load settings; falling back to defaults',
        tag: 'Settings',
        error: error,
        stackTrace: stackTrace,
      );
    }
    return const AppSettings();
  }

  Future<void> save(AppSettings settings) async {
    final file = await _settingsFile();
    await file.writeAsString(jsonEncode(settings.toJson()));
  }

  Future<File> _settingsFile() async {
    final path = await _pathProvider.configFilePath();
    final file = File(path);
    await file.parent.create(recursive: true);
    return file;
  }

  Future<bool> _maybeMigrateLegacyFile(File target) async {
    if (await target.exists()) {
      return false;
    }
    final legacyPaths = await _pathProvider.legacyConfigPaths();
    for (final legacyPath in legacyPaths) {
      final legacyFile = File(legacyPath);
      if (!await legacyFile.exists()) {
        continue;
      }
      try {
        await target.parent.create(recursive: true);
        await legacyFile.copy(target.path);
        return true;
      } catch (error, stackTrace) {
        AppLogger.w(
          'Failed to migrate legacy settings from $legacyPath',
          tag: 'Settings',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
    return false;
  }
}
