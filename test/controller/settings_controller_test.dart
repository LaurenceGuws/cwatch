import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/model/models/app_settings.dart';
import 'package:cwatch/model/models/ssh_client_backend.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/services_infra/settings/app_settings_controller.dart';
import 'package:cwatch/model/services_infra/settings/settings_storage.dart';
import 'package:cwatch/model/services_infra/ssh/builtin/builtin_ssh_key_entry.dart';
import 'package:cwatch/model/services_infra/ssh/builtin/builtin_ssh_key_service.dart';
import 'package:cwatch/controller/adapters/settings_ui_adapter.dart';
import 'package:cwatch/controller/controllers/settings_controller.dart';
import 'package:cwatch/controller/repositories/settings_repository.dart';

class FakeSettingsStorage extends SettingsStorage {
  AppSettings _settings = const AppSettings();

  @override
  Future<AppSettings> load() async => _settings;

  @override
  Future<void> save(AppSettings settings) async {
    _settings = settings;
  }

  void setSettings(AppSettings settings) {
    _settings = settings;
  }
}

class FakeBuiltInSshKeyService extends BuiltInSshKeyService {
  FakeBuiltInSshKeyService() : super(keyStore: _FakeKeyStore(), vault: _FakeVault());

  final Map<String, bool> _unlockedKeys = {};
  final List<BuiltInSshKeyEntry> _keys = [];

  @override
  bool isUnlocked(String keyId) => _unlockedKeys[keyId] ?? false;

  @override
  Future<List<BuiltInSshKeyEntry>> listKeys() async => List.unmodifiable(_keys);

  @override
  Future<BuiltInSshKeyUnlockResult> unlock(
    String keyId, {
    String? password,
  }) async {
    _unlockedKeys[keyId] = true;
    return const BuiltInSshKeyUnlockResult(
      status: BuiltInSshKeyUnlockStatus.success,
    );
  }

  void addKey(BuiltInSshKeyEntry key) {
    _keys.add(key);
  }

  void setUnlocked(String keyId, bool unlocked) {
    _unlockedKeys[keyId] = unlocked;
  }
}

class _FakeKeyStore extends BuiltInSshKeyStore {
  _FakeKeyStore() : super();
}

class _FakeVault extends BuiltInSshVault {
  _FakeVault() : super(keyStore: _FakeKeyStore());
}

class FakeSettingsUiAdapter extends SettingsUiAdapter {
  FakeSettingsUiAdapter() : super(context: _FakeBuildContext());

  final List<String> _snackBarMessages = [];
  SettingsPickedFile? _pickedSshConfig;
  SettingsPickedFile? _pickedKeyFile;
  String? _pickedKubeconfig;
  String? _promptedPassword;
  String? _promptedPassphrase;
  bool? _deleteConfirmation;

  List<String> get snackBarMessages => List.unmodifiable(_snackBarMessages);
  SettingsPickedFile? get pickedSshConfig => _pickedSshConfig;
  SettingsPickedFile? get pickedKeyFile => _pickedKeyFile;
  String? get pickedKubeconfig => _pickedKubeconfig;
  String? get promptedPassword => _promptedPassword;
  String? get promptedPassphrase => _promptedPassphrase;
  bool? get deleteConfirmation => _deleteConfirmation;

  @override
  void showSnackBar(String message, {bool isError = false, Duration? duration}) {
    _snackBarMessages.add(message);
  }

  @override
  Future<SettingsPickedFile?> pickSshConfigFile() async => _pickedSshConfig;

  @override
  Future<SettingsPickedFile?> pickPrivateKeyFile() async => _pickedKeyFile;

  @override
  Future<String?> pickKubeconfigFile() async => _pickedKubeconfig;

  @override
  Future<String?> promptForPassword({
    required String title,
    String labelText = 'Password',
    String? helperText,
    String confirmLabel = 'Unlock',
    String cancelLabel = 'Cancel',
  }) async => _promptedPassword;

  @override
  Future<String?> promptForKeyPassphrase({required bool isRequired}) async =>
      _promptedPassphrase;

  @override
  Future<bool> confirmDeleteKeyInUse({required List<String> hostNames}) async =>
      _deleteConfirmation ?? false;

  void setPickedSshConfig(SettingsPickedFile? file) => _pickedSshConfig = file;
  void setPickedKeyFile(SettingsPickedFile? file) => _pickedKeyFile = file;
  void setPickedKubeconfig(String? path) => _pickedKubeconfig = path;
  void setPromptedPassword(String? password) => _promptedPassword = password;
  void setPromptedPassphrase(String? passphrase) => _promptedPassphrase = passphrase;
  void setDeleteConfirmation(bool? confirmed) => _deleteConfirmation = confirmed;
}

class _FakeBuildContext {
  // Minimal fake BuildContext
}

class FakeSettingsRepository extends SettingsRepository {
  String? _persistedPath;

  String? get persistedPath => _persistedPath;

  @override
  Future<String?> persistSshConfig({
    required String name,
    required List<int> bytes,
  }) async {
    _persistedPath = '/fake/path/$name';
    return _persistedPath;
  }
}

void main() {
  group('SettingsController', () {
    late FakeSettingsStorage storage;
    late AppSettingsController appSettingsController;
    late FakeBuiltInSshKeyService keyService;
    late FakeSettingsUiAdapter uiAdapter;
    late FakeSettingsRepository repository;
    late SettingsController controller;

    setUp(() {
      storage = FakeSettingsStorage();
      appSettingsController = AppSettingsController(storage: storage);
      keyService = FakeBuiltInSshKeyService();
      uiAdapter = FakeSettingsUiAdapter();
      repository = FakeSettingsRepository();
    });

    Future<void> initializeController() async {
      await appSettingsController.load();
      controller = SettingsController(
        settingsController: appSettingsController,
        keyService: keyService,
        hostsFuture: Future.value(<SshHost>[]),
        uiAdapter: uiAdapter,
        repository: repository,
      );
    }

    test('initializes with settings from controller', () async {
      await initializeController();

      expect(controller.settings, isNotNull);
      expect(controller.isLoaded, isTrue);
    });

    test('update delegates to settings controller', () async {
      await initializeController();

      await controller.update(
        (current) => current.copyWith(debugMode: true),
      );

      expect(controller.settings.debugMode, isTrue);
    });

    test('applyOverrides delegates to settings controller', () async {
      await initializeController();

      controller.applyOverrides(
        (current) => current.copyWith(zoomFactor: 1.5),
      );

      expect(controller.settings.zoomFactor, 1.5);
    });

    test('setSshClientBackend updates backend', () async {
      await initializeController();

      await controller.setSshClientBackend(SshClientBackend.builtin);

      expect(controller.settings.sshClientBackend, SshClientBackend.builtin);
    });

    test('addSshConfigFile adds config when file is picked', () async {
      await initializeController();
      uiAdapter.setPickedSshConfig(
        const SettingsPickedFile(name: 'config', path: '/path/to/config'),
      );

      await controller.addSshConfigFile();

      expect(controller.settings.customSshConfigPaths, contains('/path/to/config'));
      expect(uiAdapter.snackBarMessages.last, contains('Added SSH config'));
    });

    test('addSshConfigFile does nothing when cancelled', () async {
      await initializeController();
      uiAdapter.setPickedSshConfig(null);

      await controller.addSshConfigFile();

      expect(controller.settings.customSshConfigPaths, isEmpty);
    });

    test('addSshConfigFile shows error when file cannot be read', () async {
      await initializeController();
      uiAdapter.setPickedSshConfig(
        const SettingsPickedFile(name: 'config', path: null),
      );
      repository._persistedPath = null;

      await controller.addSshConfigFile();

      expect(uiAdapter.snackBarMessages.last, contains('Unable to read'));
    });

    test('removeSshConfigPath removes config', () async {
      await initializeController();
      await controller.update(
        (current) => current.copyWith(
          customSshConfigPaths: ['/path1', '/path2'],
        ),
      );

      await controller.removeSshConfigPath('/path1');

      expect(controller.settings.customSshConfigPaths, ['/path2']);
      expect(uiAdapter.snackBarMessages.last, 'Removed config');
    });

    test('toggleSshConfigPath enables/disables config', () async {
      await initializeController();
      await controller.update(
        (current) => current.copyWith(
          customSshConfigPaths: ['/path1'],
          disabledSshConfigPaths: [],
        ),
      );

      await controller.toggleSshConfigPath('/path1', false, {});

      expect(controller.settings.disabledSshConfigPaths, contains('/path1'));
    });

    test('addKubeconfigFile adds kubeconfig when picked', () async {
      await initializeController();
      uiAdapter.setPickedKubeconfig('/path/to/kubeconfig');

      await controller.addKubeconfigFile();

      expect(controller.settings.kubernetesConfigPaths, contains('/path/to/kubeconfig'));
    });

    test('removeKubeconfigPath removes kubeconfig', () async {
      await initializeController();
      await controller.update(
        (current) => current.copyWith(
          kubernetesConfigPaths: ['/path1', '/path2'],
        ),
      );

      await controller.removeKubeconfigPath('/path1');

      expect(controller.settings.kubernetesConfigPaths, ['/path2']);
    });

    test('isKeyUnlocked delegates to key service', () async {
      await initializeController();
      keyService.setUnlocked('key1', true);

      expect(controller.isKeyUnlocked('key1'), isTrue);
      expect(controller.isKeyUnlocked('key2'), isFalse);
    });

    test('listBuiltInKeys delegates to key service', () async {
      await initializeController();
      final key = BuiltInSshKeyEntry(
        id: 'key1',
        label: 'Test Key',
        isEncrypted: false,
        fingerprint: 'fp1',
      );
      keyService.addKey(key);

      final keys = await controller.listBuiltInKeys();

      expect(keys.length, 1);
      expect(keys.first.id, 'key1');
    });

    test('notifies listeners when settings change', () async {
      await initializeController();
      var notified = false;
      controller.addListener(() {
        notified = true;
      });

      await controller.update((current) => current.copyWith(debugMode: true));

      expect(notified, isTrue);
    });
  });
}
