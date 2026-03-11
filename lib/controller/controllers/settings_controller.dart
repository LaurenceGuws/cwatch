import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'package:cwatch/model/models/app_settings.dart';
import 'package:cwatch/model/models/input_mode_preference.dart';
import 'package:cwatch/model/models/kubernetes_backend.dart';
import 'package:cwatch/model/models/ssh_client_backend.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/services_infra/settings/app_settings_controller.dart';
import 'package:cwatch/model/services_infra/ssh/builtin/builtin_ssh_key_service.dart';

import '../adapters/settings_ui_adapter.dart';
import '../repositories/settings_repository.dart';
import 'built_in_ssh_key_controller.dart';
import 'settings_update_support.dart';

class SettingsController extends ChangeNotifier {
  SettingsController({
    required this.settingsController,
    required this.keyService,
    required this.hostsFuture,
    required this.uiAdapter,
    SettingsRepository? repository,
  }) : repository = repository ?? SettingsRepository() {
    _settingsListener = notifyListeners;
    settingsController.addListener(_settingsListener);
    keyController = BuiltInSshKeyController(
      settingsController: settingsController,
      keyService: keyService,
      hostsFuture: hostsFuture,
      ui: uiAdapter,
      updateSettings: update,
    );
  }

  final AppSettingsController settingsController;
  final BuiltInSshKeyService keyService;
  final Future<List<SshHost>> hostsFuture;
  final SettingsUiAdapter uiAdapter;
  final SettingsRepository repository;
  late final BuiltInSshKeyController keyController;

  late final VoidCallback _settingsListener;

  AppSettings get settings => settingsController.settings;
  bool get isLoaded => settingsController.isLoaded;

  Future<void> update(
    AppSettings Function(AppSettings current) transform,
  ) async {
    await settingsController.update(transform);
  }

  Future<void> setThemeMode(ThemeMode value) async {
    await update(
      (current) => SettingsUpdateSupport.setThemeMode(current, value),
    );
  }

  Future<void> setDebugMode(bool value) async {
    await update(
      (current) => SettingsUpdateSupport.setDebugMode(current, value),
    );
  }

  Future<void> setZoomFactor(double value) async {
    await update(
      (current) => SettingsUpdateSupport.setZoomFactor(current, value),
    );
  }

  Future<void> setAppFontFamily(String value) async {
    await update(
      (current) => SettingsUpdateSupport.setAppFontFamily(current, value),
    );
  }

  Future<void> setAppThemeKey(String value) async {
    await update(
      (current) => SettingsUpdateSupport.setAppThemeKey(current, value),
    );
  }

  Future<void> setUiDensity(AppUiDensity value) async {
    await update(
      (current) => SettingsUpdateSupport.setUiDensity(current, value),
    );
  }

  Future<void> setInputModePreference(InputModePreference value) async {
    await update(
      (current) => SettingsUpdateSupport.setInputModePreference(current, value),
    );
  }

  Future<void> setDockerLogsTail(int value) async {
    await update(
      (current) => SettingsUpdateSupport.setDockerLogsTail(current, value),
    );
  }

  Future<void> setUploadConcurrency(int value) async {
    await update(
      (current) => SettingsUpdateSupport.setUploadConcurrency(current, value),
    );
  }

  Future<void> setDownloadConcurrency(int value) async {
    await update(
      (current) => SettingsUpdateSupport.setDownloadConcurrency(current, value),
    );
  }

  Future<void> setUseSystemDecorations(bool value) async {
    await update(
      (current) =>
          SettingsUpdateSupport.setUseSystemDecorations(current, value),
    );
  }

  Future<void> setCloseToTray(bool value) async {
    await update(
      (current) => SettingsUpdateSupport.setCloseToTray(current, value),
    );
  }

  Future<void> setExplorerRowHeight(double value) async {
    await update(
      (current) => SettingsUpdateSupport.setExplorerRowHeight(current, value),
    );
  }

  Future<void> setExplorerShowBreadcrumbs(bool value) async {
    await update(
      (current) =>
          SettingsUpdateSupport.setExplorerShowBreadcrumbs(current, value),
    );
  }

  Future<void> setServerShowOffline(bool value) async {
    await update(
      (current) => SettingsUpdateSupport.setServerShowOffline(current, value),
    );
  }

  Future<void> setServerAutoRefresh(bool value) async {
    await update(
      (current) => SettingsUpdateSupport.setServerAutoRefresh(current, value),
    );
  }

  Future<void> enableServerHost(String hostKey) async {
    await update(
      (current) => SettingsUpdateSupport.enableServerHost(current, hostKey),
    );
  }

  Future<void> setKubernetesBackend(KubernetesBackend value) async {
    await update(
      (current) => SettingsUpdateSupport.setKubernetesBackend(current, value),
    );
  }

  Future<void> setKubernetesCliCommand(String value) async {
    await update(
      (current) =>
          SettingsUpdateSupport.setKubernetesCliCommand(current, value),
    );
  }

  Future<void> setShortcutBinding(String shortcutId, String? value) async {
    await update(
      (current) => SettingsUpdateSupport.setShortcutBinding(
        current,
        shortcutId: shortcutId,
        value: value,
      ),
    );
  }

  Future<void> setTerminalFontFamily(String value) async {
    await update(
      (current) => SettingsUpdateSupport.setTerminalFontFamily(current, value),
    );
  }

  Future<void> setTerminalFontSize(double value) async {
    await update(
      (current) => SettingsUpdateSupport.setTerminalFontSize(current, value),
    );
  }

  Future<void> setTerminalLineHeight(double value) async {
    await update(
      (current) => SettingsUpdateSupport.setTerminalLineHeight(current, value),
    );
  }

  Future<void> setTerminalPaddingX(double value) async {
    await update(
      (current) => SettingsUpdateSupport.setTerminalPaddingX(current, value),
    );
  }

  Future<void> setTerminalPaddingY(double value) async {
    await update(
      (current) => SettingsUpdateSupport.setTerminalPaddingY(current, value),
    );
  }

  Future<void> setTerminalDarkTheme(String value) async {
    await update(
      (current) => SettingsUpdateSupport.setTerminalDarkTheme(current, value),
    );
  }

  Future<void> setTerminalLightTheme(String value) async {
    await update(
      (current) => SettingsUpdateSupport.setTerminalLightTheme(current, value),
    );
  }

  Future<void> setEditorFontFamily(String value) async {
    await update(
      (current) => SettingsUpdateSupport.setEditorFontFamily(current, value),
    );
  }

  Future<void> setEditorFontSize(double value) async {
    await update(
      (current) => SettingsUpdateSupport.setEditorFontSize(current, value),
    );
  }

  Future<void> setEditorLineHeight(double value) async {
    await update(
      (current) => SettingsUpdateSupport.setEditorLineHeight(current, value),
    );
  }

  Future<void> setEditorLightTheme(String value) async {
    await update(
      (current) => SettingsUpdateSupport.setEditorLightTheme(current, value),
    );
  }

  Future<void> setEditorDarkTheme(String value) async {
    await update(
      (current) => SettingsUpdateSupport.setEditorDarkTheme(current, value),
    );
  }

  void applyOverrides(AppSettings Function(AppSettings current) transform) {
    settingsController.applyOverrides(transform);
  }

  bool get supportsPlatformSsh {
    if (kIsWeb) return false;
    return Platform.isLinux || Platform.isMacOS || Platform.isWindows;
  }

  Future<void> ensureSupportedSshBackend() async {
    if (supportsPlatformSsh) return;
    if (settings.sshPreferences.clientBackend == SshClientBackend.builtin) {
      return;
    }
    await update(
      (current) => current.copyWith(
        sshPreferences: current.sshPreferences.copyWith(
          clientBackend: SshClientBackend.builtin,
        ),
      ),
    );
  }

  Future<void> setSshClientBackend(SshClientBackend target) async {
    await update(
      (current) => current.copyWith(
        sshPreferences: current.sshPreferences.copyWith(clientBackend: target),
      ),
    );
  }

  Future<void> addSshConfigFile() async {
    final picked = await uiAdapter.pickSshConfigFile();
    if (picked == null) return;
    String? path = picked.path;
    if (path == null && picked.bytes != null) {
      path = await repository.persistSshConfig(
        name: picked.name,
        bytes: picked.bytes!,
      );
    }
    if (path == null) {
      uiAdapter.showSnackBar('Unable to read selected file', isError: true);
      return;
    }
    final normalized = p.normalize(path);
    final current = settings.sshPreferences.customConfigPaths;
    if (current.contains(normalized)) {
      uiAdapter.showSnackBar('Config already added');
      return;
    }
    await update(
      (settings) => settings.copyWith(
        sshPreferences: settings.sshPreferences.copyWith(
          customConfigPaths: [...current, normalized],
        ),
      ),
    );
    uiAdapter.showSnackBar('Added SSH config: ${p.basename(normalized)}');
  }

  Future<void> removeSshConfigPath(String path) async {
    final current = settings.sshPreferences.customConfigPaths;
    final next = [...current]..remove(path);
    await update(
      (settings) => settings.copyWith(
        sshPreferences: settings.sshPreferences.copyWith(
          customConfigPaths: next,
        ),
      ),
    );
    uiAdapter.showSnackBar('Removed config');
  }

  Future<void> toggleSshConfigPath(
    String path,
    bool enabled,
    Set<String> disabled,
  ) async {
    final next = disabled.toSet();
    if (enabled) {
      next.remove(path);
    } else {
      next.add(path);
    }
    await update(
      (settings) => settings.copyWith(
        sshPreferences: settings.sshPreferences.copyWith(
          disabledConfigPaths: next.toList(),
        ),
      ),
    );
    uiAdapter.showSnackBar(enabled ? 'Enabled $path' : 'Disabled $path');
  }

  Future<void> addKubeconfigFile() async {
    final path = await uiAdapter.pickKubeconfigFile();
    if (path == null) return;
    final normalized = p.normalize(path);
    final current = settings.kubernetesPreferences.configPaths;
    if (current.contains(normalized)) return;
    await update(
      (settings) => settings.copyWith(
        kubernetesPreferences: settings.kubernetesPreferences.copyWith(
          configPaths: [...current, normalized],
        ),
      ),
    );
  }

  Future<void> removeKubeconfigPath(String path) async {
    final current = settings.kubernetesPreferences.configPaths;
    final next = [...current]..remove(path);
    await update(
      (settings) => settings.copyWith(
        kubernetesPreferences: settings.kubernetesPreferences.copyWith(
          configPaths: next,
        ),
      ),
    );
  }

  @override
  void dispose() {
    settingsController.removeListener(_settingsListener);
    super.dispose();
  }
}
