import 'package:flutter/widgets.dart';

import '../../models/app_settings.dart';
import 'settings_storage.dart';

class AppSettingsController extends ChangeNotifier {
  AppSettingsController({
    SettingsStorage? storage,
  }) : _storage = storage ?? SettingsStorage();

  final SettingsStorage _storage;

  AppSettings _settings = const AppSettings();
  bool _loaded = false;

  AppSettings get settings => _settings;
  bool get isLoaded => _loaded;

  Future<void> load() async {
    _settings = await _storage.load();
    _loaded = true;
    notifyListeners();
  }

  Future<void> update(AppSettings Function(AppSettings current) transform) async {
    _settings = transform(_settings);
    notifyListeners();
    await _storage.save(_settings);
  }
}
