import 'dart:convert';
import 'dart:io';

import '../../models/app_settings.dart';
import 'settings_path_provider.dart';

class SettingsStorage {
  SettingsStorage({
    SettingsPathProvider? pathProvider,
  }) : _pathProvider = pathProvider ?? const SettingsPathProvider();

  final SettingsPathProvider _pathProvider;

  Future<AppSettings> load() async {
    final file = await _settingsFile();
    if (!await file.exists()) {
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
    } catch (_) {
      // Ignore and fall back to defaults below.
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
}
