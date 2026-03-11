import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/controller/adapters/settings_key_ui.dart';
import 'package:cwatch/controller/controllers/built_in_ssh_key_controller.dart';
import 'package:cwatch/model/models/app_settings.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/models/ssh_preferences.dart';
import 'package:cwatch/model/services_infra/settings/app_settings_controller.dart';
import 'package:cwatch/model/services_infra/ssh/builtin/builtin_ssh_key_entry.dart';
import 'package:cwatch/model/services_infra/ssh/builtin/builtin_ssh_key_service.dart';

void main() {
  test('addBuiltInKey asks for passphrase when key service requests it', () async {
    final ui = _FakeSettingsKeyUi()..passphrase = 'secret';
    final service = _FakeBuiltInSshKeyService()
      ..addKeyResults = [
        const BuiltInSshKeyAddResult(
          status: BuiltInSshKeyAddStatus.needsPassphrase,
        ),
        const BuiltInSshKeyAddResult(status: BuiltInSshKeyAddStatus.success),
      ];
    final controller = _controller(ui: ui, keyService: service);

    final added = await controller.addBuiltInKey(
      label: 'deploy',
      keyText: 'pem',
    );

    expect(added, isTrue);
    expect(ui.promptedForPassphrase, isTrue);
    expect(ui.messages, contains('Key added to the vault.'));
  });

  test('removeBuiltInKey clears host binding after confirmation', () async {
    final settingsController = AppSettingsController()
      ..applyOverrides(
        (_) => AppSettings(
          sshPreferences: const SshPreferences(
            builtinHostKeyBindings: {'prod': 'key-1'},
          ),
        ),
      );
    final ui = _FakeSettingsKeyUi()..confirmDelete = true;
    final service = _FakeBuiltInSshKeyService();
    final controller = BuiltInSshKeyController(
      settingsController: settingsController,
      keyService: service,
      hostsFuture: Future.value(
        const [
          SshHost(
            name: 'prod',
            hostname: 'prod.example',
            port: 22,
            available: true,
          ),
        ],
      ),
      ui: ui,
      updateSettings: settingsController.update,
    );

    final removed = await controller.removeBuiltInKey('key-1');

    expect(removed, isTrue);
    expect(
      settingsController.settings.sshPreferences.builtinHostKeyBindings,
      isEmpty,
    );
    expect(service.deletedKeys, ['key-1']);
  });

  test('updateHostBinding writes builtin host key binding through settings', () async {
    final settingsController = AppSettingsController()
      ..applyOverrides((_) => const AppSettings());
    final controller = BuiltInSshKeyController(
      settingsController: settingsController,
      keyService: _FakeBuiltInSshKeyService(),
      hostsFuture: Future.value(const <SshHost>[]),
      ui: _FakeSettingsKeyUi(),
      updateSettings: settingsController.update,
    );

    await controller.updateHostBinding('prod', 'key-1');

    expect(
      settingsController.settings.sshPreferences.builtinHostKeyBindings,
      {'prod': 'key-1'},
    );
  });
}

BuiltInSshKeyController _controller({
  required _FakeSettingsKeyUi ui,
  required _FakeBuiltInSshKeyService keyService,
}) {
  final settingsController = AppSettingsController()
    ..applyOverrides((_) => const AppSettings());
  return BuiltInSshKeyController(
    settingsController: settingsController,
    keyService: keyService,
    hostsFuture: Future.value(const <SshHost>[]),
    ui: ui,
    updateSettings: settingsController.update,
  );
}

class _FakeSettingsKeyUi implements SettingsKeyUi {
  final List<String> messages = <String>[];
  String? passphrase;
  bool confirmDelete = false;
  bool promptedForPassphrase = false;

  @override
  Future<bool> confirmDeleteKeyInUse({required List<String> hostNames}) async {
    return confirmDelete;
  }

  @override
  Future<SettingsPickedFile?> pickPrivateKeyFile() async => null;

  @override
  Future<String?> promptForKeyPassphrase({required bool isRequired}) async {
    promptedForPassphrase = true;
    return passphrase;
  }

  @override
  Future<String?> promptForPassword({
    required String title,
    String labelText = 'Password',
    String? helperText,
    String confirmLabel = 'Unlock',
    String cancelLabel = 'Cancel',
  }) async {
    return null;
  }

  @override
  void showSnackBar(
    String message, {
    bool isError = false,
    Duration? duration,
  }) {
    messages.add(message);
  }
}

class _FakeBuiltInSshKeyService extends BuiltInSshKeyService {
  List<BuiltInSshKeyAddResult> addKeyResults = <BuiltInSshKeyAddResult>[];
  final List<String> deletedKeys = <String>[];

  @override
  Future<BuiltInSshKeyAddResult> addKey({
    required String label,
    required String keyPem,
    String? storagePassword,
    String? keyPassphrase,
  }) async {
    return addKeyResults.removeAt(0);
  }

  @override
  Future<void> deleteKey(String id) async {
    deletedKeys.add(id);
  }

  @override
  Future<BuiltInSshKeyEntry?> loadKey(String id) async => null;
}
