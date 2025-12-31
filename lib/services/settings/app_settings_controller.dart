import 'package:flutter/widgets.dart';

import '../../models/app_settings.dart';
import '../logging/app_logger.dart';
import 'settings_storage.dart';

class AppSettingsController extends ChangeNotifier {
  AppSettingsController({SettingsStorage? storage})
    : _storage = storage ?? SettingsStorage();

  final SettingsStorage _storage;

  AppSettings _settings = const AppSettings();
  bool _loaded = false;

  AppSettings get settings => _settings;
  bool get isLoaded => _loaded;

  Future<void> load() async {
    _settings = await _storage.load();
    _loaded = true;
    AppLogger.configureRemoteCommandLogging(
      enabled: _settings.debugMode,
    );
    notifyListeners();
  }

  Future<void> update(
    AppSettings Function(AppSettings current) transform,
  ) async {
    _settings = transform(_settings);
    AppLogger.configureRemoteCommandLogging(
      enabled: _settings.debugMode,
    );
    notifyListeners();
    await _storage.save(_settings);
  }

  void applyOverrides(AppSettings Function(AppSettings current) transform) {
    _settings = transform(_settings);
    AppLogger.configureRemoteCommandLogging(
      enabled: _settings.debugMode,
    );
    notifyListeners();
  }
}
