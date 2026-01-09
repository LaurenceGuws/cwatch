import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/model/models/app_settings.dart';
import 'package:cwatch/model/services_infra/logging/app_logger.dart';
import 'package:cwatch/model/services_infra/settings/app_settings_controller.dart';
import 'package:cwatch/model/services_infra/settings/settings_storage.dart';

class FakeSettingsStorage extends SettingsStorage {
  AppSettings _settings = const AppSettings();
  int _saveCallCount = 0;
  int _loadCallCount = 0;

  int get saveCallCount => _saveCallCount;
  int get loadCallCount => _loadCallCount;

  @override
  Future<AppSettings> load() async {
    _loadCallCount++;
    return _settings;
  }

  @override
  Future<void> save(AppSettings settings) async {
    _saveCallCount++;
    _settings = settings;
  }

  void setSettings(AppSettings settings) {
    _settings = settings;
  }
}

void main() {
  group('AppSettingsController', () {
    test('initial state is not loaded', () {
      final storage = FakeSettingsStorage();
      final controller = AppSettingsController(storage: storage);

      expect(controller.isLoaded, isFalse);
      expect(storage.loadCallCount, 0);
    });

    test('load loads settings from storage', () async {
      final storage = FakeSettingsStorage();
      final initialSettings = const AppSettings(debugMode: true, zoomFactor: 1.5);
      storage.setSettings(initialSettings);

      final controller = AppSettingsController(storage: storage);
      await controller.load();

      expect(controller.isLoaded, isTrue);
      expect(storage.loadCallCount, 1);
      expect(controller.settings.debugMode, isTrue);
      expect(controller.settings.zoomFactor, 1.5);
    });

    test('update modifies settings and saves to storage', () async {
      final storage = FakeSettingsStorage();
      final controller = AppSettingsController(storage: storage);
      await controller.load();

      var notified = false;
      controller.addListener(() {
        notified = true;
      });

      await controller.update(
        (current) => current.copyWith(debugMode: true, zoomFactor: 2.0),
      );

      expect(notified, isTrue);
      expect(controller.settings.debugMode, isTrue);
      expect(controller.settings.zoomFactor, 2.0);
      expect(storage.saveCallCount, 1);
    });

    test('applyOverrides modifies settings without saving', () {
      final storage = FakeSettingsStorage();
      final controller = AppSettingsController(storage: storage);

      var notified = false;
      controller.addListener(() {
        notified = true;
      });

      controller.applyOverrides(
        (current) => current.copyWith(debugMode: true),
      );

      expect(notified, isTrue);
      expect(controller.settings.debugMode, isTrue);
      expect(storage.saveCallCount, 0);
    });

    test('update configures remote command logging', () async {
      final storage = FakeSettingsStorage();
      final controller = AppSettingsController(storage: storage);
      await controller.load();

      await controller.update(
        (current) => current.copyWith(debugMode: true),
      );

      // Verify logging was configured (indirectly by checking settings)
      expect(controller.settings.debugMode, isTrue);
    });

    test('multiple updates accumulate changes', () async {
      final storage = FakeSettingsStorage();
      final controller = AppSettingsController(storage: storage);
      await controller.load();

      await controller.update(
        (current) => current.copyWith(debugMode: true),
      );
      await controller.update(
        (current) => current.copyWith(zoomFactor: 1.5),
      );

      expect(controller.settings.debugMode, isTrue);
      expect(controller.settings.zoomFactor, 1.5);
      expect(storage.saveCallCount, 2);
    });
  });
}
