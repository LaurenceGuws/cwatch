import 'package:flutter/material.dart';

import 'package:cwatch/controller/adapters/ssh_auth_prompter.dart';
import 'package:cwatch/view/core/navigation/home_shell_services.dart';
import 'package:cwatch/model/services_infra/settings/app_settings_controller.dart';
import 'package:cwatch/model/services_infra/ssh/builtin/builtin_ssh_key_service.dart';
import 'package:cwatch/model/services_infra/ssh/builtin/builtin_ssh_key_store.dart';
import 'package:cwatch/model/services_infra/ssh/builtin/builtin_ssh_vault.dart';
import 'package:cwatch/model/services_infra/ssh/ssh_auth_coordinator.dart';
import 'package:cwatch/model/services_infra/ssh/ssh_shell_factory.dart';
import 'package:cwatch/model/services_infra/window/tray_service.dart';
import 'package:cwatch/model/services_infra/window/window_chrome_service.dart';
import 'package:cwatch/view/core/navigation/gesture_detector_factory.dart';

class HomeShellServicesBinding {
  const HomeShellServicesBinding();

  BuiltInSshKeyStore createKeyStore() {
    return BuiltInSshKeyStore();
  }

  BuiltInSshVault createVault({required BuiltInSshKeyStore keyStore}) {
    return BuiltInSshVault(keyStore: keyStore);
  }

  BuiltInSshKeyService createKeyService({
    required BuiltInSshKeyStore keyStore,
    required BuiltInSshVault vault,
  }) {
    return BuiltInSshKeyService(keyStore: keyStore, vault: vault);
  }

  SshAuthCoordinator createAuthCoordinator({
    required BuildContext context,
    required BuiltInSshKeyService keyService,
  }) {
    return SshAuthPrompter.forContext(context: context, keyService: keyService);
  }

  WindowChromeService createWindowChrome() {
    return WindowChromeService();
  }

  TrayService createTrayService() {
    return TrayService();
  }

  SshShellFactory createShellFactory({
    required AppSettingsController settingsController,
    required BuiltInSshKeyService keyService,
    required SshAuthCoordinator authCoordinator,
  }) {
    return SshShellFactory(
      settingsController: settingsController,
      keyService: keyService,
      authCoordinator: authCoordinator,
    );
  }

  GestureDetectorFactory createGestureDetectorFactory() {
    return GestureDetectorFactory();
  }

  HomeShellServices create({
    required BuildContext context,
    required AppSettingsController settingsController,
  }) {
    final services = HomeShellServices();
    final keyStore = createKeyStore();
    final vault = createVault(keyStore: keyStore);
    final keyService = createKeyService(keyStore: keyStore, vault: vault);
    final authCoordinator = createAuthCoordinator(
      context: context,
      keyService: keyService,
    );
    final windowChrome = createWindowChrome();
    final trayService = createTrayService();
    final shellFactory = createShellFactory(
      settingsController: settingsController,
      keyService: keyService,
      authCoordinator: authCoordinator,
    );
    final gestureDetectorFactory = createGestureDetectorFactory();
    services.keyStore = keyStore;
    services.vault = vault;
    services.keyService = keyService;
    services.authCoordinator = authCoordinator;
    services.windowChrome = windowChrome;
    services.trayService = trayService;
    services.shellFactory = shellFactory;
    services.gestureDetectorFactory = gestureDetectorFactory;

    return services;
  }
}
