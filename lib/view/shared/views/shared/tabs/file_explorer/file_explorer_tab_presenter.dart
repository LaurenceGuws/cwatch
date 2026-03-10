import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:cwatch/controller/controllers/file_explorer_controller.dart';
import 'package:cwatch/controller/controllers/settings_controller.dart';
import 'package:cwatch/model/models/app_settings.dart';
import 'package:cwatch/model/shared/shortcuts/input_mode_resolver.dart';
import 'package:cwatch/model/shared/shortcuts/shortcut_actions.dart';
import 'package:cwatch/model/shared/shortcuts/shortcut_resolver.dart';

class FileExplorerTabPresenter {
  FileExplorerTabPresenter({
    required this.controller,
    required this.settingsController,
  });

  final FileExplorerController controller;
  final SettingsController settingsController;

  bool showSettings = false;
  String? _lastTimeoutNotification;

  String? get errorMessage => controller.state.error;

  bool get isTimeoutError => _isTimeoutError(errorMessage);

  bool get showStreamingResults =>
      controller.state.loading &&
      controller.state.searchActive &&
      controller.state.searchQuery.trim().isNotEmpty;

  bool get showLoadingIndicator =>
      controller.state.loading && !showStreamingResults;

  void toggleSettings() {
    showSettings = !showSettings;
  }

  String? consumeTimeoutNotification() {
    final errorMessage = this.errorMessage;
    if (!isTimeoutError || errorMessage == null) {
      return null;
    }
    if (errorMessage == _lastTimeoutNotification) {
      return null;
    }
    _lastTimeoutNotification = errorMessage;
    return errorMessage;
  }

  Map<ShortcutActivator, Intent> buildShortcuts(AppSettings settings) {
    final inputMode = resolveInputMode(
      settings.inputModePreference,
      defaultTargetPlatform,
    );
    if (!inputMode.enableShortcuts) {
      return const {};
    }

    final resolver = ShortcutResolver(settings);
    final map = <ShortcutActivator, Intent>{};

    void add(String id, Intent intent) {
      final binding = resolver.bindingFor(id);
      if (binding == null) return;
      map[binding.toActivator()] = intent;
    }

    add(ShortcutActions.explorerSearch, const ToggleSearchIntent());
    add(ShortcutActions.explorerZoomIn, const ZoomInIntent());
    add(ShortcutActions.explorerZoomOut, const ZoomOutIntent());

    return map;
  }

  bool _isTimeoutError(String? message) {
    if (message == null || message.isEmpty) {
      return false;
    }
    return message.contains('TimeoutException') ||
        message.toLowerCase().contains('timed out');
  }
}

class ToggleSearchIntent extends Intent {
  const ToggleSearchIntent();
}

class ZoomInIntent extends Intent {
  const ZoomInIntent();
}

class ZoomOutIntent extends Intent {
  const ZoomOutIntent();
}
