import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/model/features/servers/services/host_distro_key.dart';
import 'package:cwatch/model/features/servers/services/host_distro_manager.dart';
import 'package:cwatch/model/models/custom_ssh_host.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/services_infra/cache/cache_storage.dart';
import 'package:cwatch/model/services_infra/cache/distro_cache_controller.dart';
import 'package:cwatch/model/services_infra/settings/app_settings_controller.dart';
import 'package:cwatch/model/services_infra/ssh/builtin/builtin_ssh_key_service.dart';
import 'package:cwatch/model/services_infra/ssh/ssh_shell_factory.dart';
import 'package:cwatch/view/features/servers/server_host_surface_controller.dart';

void main() {
  group('ServerHostSurfaceController', () {
    test('buildCustomHostsSignature is stable regardless of host order', () {
      final settingsController = AppSettingsController();
      settingsController.applyOverrides(
        (current) => current.copyWith(
          sshPreferences: current.sshPreferences.copyWith(
            customHosts: const [
              CustomSshHost(
                name: 'beta',
                hostname: 'beta.example.com',
                port: 22,
              ),
              CustomSshHost(
                name: 'alpha',
                hostname: 'alpha.example.com',
                port: 2200,
              ),
            ],
          ),
        ),
      );
      final controller = ServerHostSurfaceController(
        appSettingsController: settingsController,
        distroManager: _fakeDistroManagerFactory,
      );

      final first = controller.buildCustomHostsSignature();

      settingsController.applyOverrides(
        (current) => current.copyWith(
          sshPreferences: current.sshPreferences.copyWith(
            customHosts: const [
              CustomSshHost(
                name: 'alpha',
                hostname: 'alpha.example.com',
                port: 2200,
              ),
              CustomSshHost(
                name: 'beta',
                hostname: 'beta.example.com',
                port: 22,
              ),
            ],
          ),
        ),
      );

      expect(controller.buildCustomHostsSignature(), first);
    });

    test('buildPathsSignature sorts custom and disabled config paths', () {
      final settingsController = AppSettingsController();
      settingsController.applyOverrides(
        (current) => current.copyWith(
          sshPreferences: current.sshPreferences.copyWith(
            customConfigPaths: const ['/b.conf', '/a.conf'],
            disabledConfigPaths: const ['/disabled-b', '/disabled-a'],
          ),
        ),
      );
      final controller = ServerHostSurfaceController(
        appSettingsController: settingsController,
        distroManager: _fakeDistroManagerFactory,
      );

      expect(
        controller.buildPathsSignature(),
        '{"customPaths":["/a.conf","/b.conf"],"disabledPaths":["/disabled-a","/disabled-b"]}',
      );
    });

    test('updateCustomHosts preserves non-custom hosts and existing availability', () async {
      final controller = ServerHostSurfaceController(
        appSettingsController: AppSettingsController(),
        distroManager: _fakeDistroManagerFactory,
      );
      controller.lastHosts = const [
        SshHost(
          name: 'ssh-config',
          hostname: 'ssh.example.com',
          port: 22,
          available: true,
          source: '/home/user/.ssh/config',
        ),
        SshHost(
          name: 'custom-a',
          hostname: 'custom-a.example.com',
          port: 2222,
          available: true,
          user: 'root',
          identityFiles: ['/id_a'],
          source: 'custom',
        ),
      ];

      final updated = await controller.updateCustomHosts(const [
        CustomSshHost(
          name: 'custom-a',
          hostname: 'custom-a.example.com',
          port: 2222,
          user: 'root',
          identityFile: '/id_a',
        ),
      ], onHostsChanged: () {});

      expect(updated, hasLength(2));
      expect(updated.first.source, '/home/user/.ssh/config');
      expect(updated.last.source, 'custom');
      expect(updated.last.available, isTrue);
    });

    test('ensureDistroForHostOnDemand forces lookup only for newly available host', () async {
      final fakeManager = _FakeHostDistroManager();
      final controller = ServerHostSurfaceController(
        appSettingsController: AppSettingsController(),
        distroManager: () => fakeManager,
      );
      const host = SshHost(
        name: 'alpha',
        hostname: 'alpha.example.com',
        port: 22,
        available: true,
      );

      controller.trackHostDistroChecks(const [host], disabledHostKeys: const {});
      controller.ensureDistroForHostOnDemand(host, disabledHostKeys: const {});
      await Future<void>.delayed(Duration.zero);

      expect(fakeManager.ensureCalls, 1);
      expect(fakeManager.forcedValues, [false]);

      controller.resetAvailabilityTracking();
      fakeManager.cachedKeys.clear();
      controller.ensureDistroForHostOnDemand(host, disabledHostKeys: const {});
      await Future<void>.delayed(Duration.zero);

      expect(fakeManager.ensureCalls, 2);
      expect(fakeManager.forcedValues, [false, true]);
    });
  });
}

HostDistroManager _fakeDistroManagerFactory() => _FakeHostDistroManager();

class _FakeHostDistroManager extends HostDistroManager {
  _FakeHostDistroManager()
    : super(
        distroCacheController: DistroCacheController(storage: _MemoryCacheStorage()),
        disabledHostKeys: () => const {},
        shellFactory: SshShellFactory(
          settingsController: AppSettingsController(),
          keyService: BuiltInSshKeyService(),
        ),
      );

  int ensureCalls = 0;
  final List<bool> forcedValues = [];
  final Set<String> cachedKeys = {};

  @override
  bool hasCached(String key) => cachedKeys.contains(key);

  @override
  Future<void> ensureDistroForHost(
    SshHost host, {
    bool force = false,
    bool allowUnavailable = false,
  }) async {
    ensureCalls += 1;
    forcedValues.add(force);
    cachedKeys.add(hostDistroCacheKey(host));
  }
}

class _MemoryCacheStorage extends CacheStorage {
  _MemoryCacheStorage() : super();

  final Map<String, Map<String, String>> _maps = {};

  @override
  Future<Map<String, String>> readStringMap(String key) async => _maps[key] ?? const {};

  @override
  Future<void> writeStringMap(String key, Map<String, String> values) async {
    _maps[key] = Map<String, String>.from(values);
  }
}
