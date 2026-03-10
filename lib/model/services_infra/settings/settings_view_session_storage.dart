import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import '../logging/app_logger.dart';
import 'settings_path_provider.dart';

class SettingsViewSessionStorage {
  SettingsViewSessionStorage({SettingsPathProvider? pathProvider})
    : _pathProvider = pathProvider ?? const SettingsPathProvider();

  final SettingsPathProvider _pathProvider;

  Future<int> loadTabIndex({int fallback = 0}) async {
    final file = await _sessionFile();
    if (!await file.exists()) {
      return fallback;
    }
    try {
      final contents = await file.readAsString();
      final dynamic decoded = jsonDecode(contents);
      if (decoded is Map<String, dynamic>) {
        final raw = decoded['selectedTabIndex'];
        if (raw is num) {
          return raw.toInt();
        }
      }
    } catch (error, stackTrace) {
      AppLogger().warn(
        'Failed to load settings view session state',
        tag: 'Settings',
        error: error,
        stackTrace: stackTrace,
      );
    }
    return fallback;
  }

  Future<void> saveTabIndex(int index) async {
    final file = await _sessionFile();
    final encoded = await Isolate.run(
      () => jsonEncode({'selectedTabIndex': index}),
    );
    await file.writeAsString(encoded);
  }

  Future<File> _sessionFile() async {
    final directory = await _pathProvider.configDirectory();
    final file = File('$directory/settings_view_session.json');
    await file.parent.create(recursive: true);
    return file;
  }
}
