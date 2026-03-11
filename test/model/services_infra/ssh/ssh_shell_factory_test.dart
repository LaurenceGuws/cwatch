import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/model/models/app_settings.dart';
import 'package:cwatch/model/models/ssh_client_backend.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/models/ssh_preferences.dart';
import 'package:cwatch/model/services_infra/settings/app_settings_controller.dart';
import 'package:cwatch/model/services_infra/ssh/builtin/builtin_remote_shell_service.dart';
import 'package:cwatch/model/services_infra/ssh/builtin/builtin_ssh_key_service.dart';
import 'package:cwatch/model/services_infra/ssh/process_ssh_shell_service.dart';
import 'package:cwatch/model/services_infra/ssh/ssh_shell_factory.dart';

void main() {
  group('SshShellFactory', () {
    test('uses process shell when platform backend is selected', () {
      final controller = AppSettingsController()
        ..applyOverrides(
          (_) => _settings(
            sshPreferences: const SshPreferences(
              clientBackend: SshClientBackend.platform,
            ),
          ),
        );
      final factory = SshShellFactory(
        settingsController: controller,
        keyService: BuiltInSshKeyService(),
      );

      final shell = factory.forHost(_host());

      expect(shell, isA<ProcessRemoteShellService>());
    });

    test('reuses builtin shell for matching default request', () {
      final controller = AppSettingsController()
        ..applyOverrides((_) => _settings());
      final factory = SshShellFactory(
        settingsController: controller,
        keyService: BuiltInSshKeyService(),
      );

      final first = factory.forHost(_host());
      final second = factory.forHost(_host());

      expect(first, isA<BuiltInRemoteShellService>());
      expect(identical(first, second), isTrue);
    });

    test('treats timeout request as a distinct builtin runtime', () {
      final controller = AppSettingsController()
        ..applyOverrides((_) => _settings());
      final factory = SshShellFactory(
        settingsController: controller,
        keyService: BuiltInSshKeyService(),
      );

      final defaultShell = factory.forHost(_host());
      final timedShell = factory.forHost(
        _host(),
        connectTimeout: const Duration(seconds: 5),
      );
      final timedShellAgain = factory.forHost(
        _host(),
        connectTimeout: const Duration(seconds: 5),
      );

      expect(defaultShell, isA<BuiltInRemoteShellService>());
      expect(timedShell, isA<BuiltInRemoteShellService>());
      expect(identical(defaultShell, timedShell), isFalse);
      expect(identical(timedShell, timedShellAgain), isTrue);
    });

    test('resets cached runtime when selector signature changes', () {
      final controller = AppSettingsController()
        ..applyOverrides((_) => _settings());
      final factory = SshShellFactory(
        settingsController: controller,
        keyService: BuiltInSshKeyService(),
      );

      final first = factory.forHost(_host());
      controller.applyOverrides((_) => _settings(debugMode: true));
      factory.handleSettingsChanged(controller.settings);
      final second = factory.forHost(_host());

      expect(identical(first, second), isFalse);
    });
  });
}

AppSettings _settings({
  bool debugMode = false,
  SshPreferences sshPreferences = const SshPreferences(
    clientBackend: SshClientBackend.builtin,
  ),
}) {
  return AppSettings(debugMode: debugMode, sshPreferences: sshPreferences);
}

SshHost _host() {
  return const SshHost(
    name: 'example',
    hostname: 'example.local',
    port: 22,
    available: true,
  );
}
