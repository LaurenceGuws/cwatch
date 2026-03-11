import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/view/core/tabs/workspace_host_lifecycle.dart';

void main() {
  group('WorkspaceHostLifecycle', () {
    test('initialize wires listeners, shell chrome, and restore', () async {
      final workspace = ChangeNotifier();
      final settings = ChangeNotifier();
      final events = <String>[];
      final lifecycle = WorkspaceHostLifecycle(
        workspaceListenable: workspace,
        settingsListenable: settings,
        requestRefresh: () {
          events.add('refresh');
        },
        handleSettingsChanged: () async {
          events.add('settings');
        },
        restoreWorkspace: () async {
          events.add('restore');
        },
        initializeShellChrome: () {
          events.add('chrome:init');
        },
        disposeShellChrome: () {
          events.add('chrome:dispose');
        },
      );

      lifecycle.initialize();
      await Future<void>.delayed(Duration.zero);
      workspace.notifyListeners();
      settings.notifyListeners();
      await Future<void>.delayed(Duration.zero);

      expect(
        events,
        containsAllInOrder(['chrome:init', 'restore', 'refresh', 'settings']),
      );
    });

    test('dispose unwires listeners and shell chrome', () async {
      final workspace = ChangeNotifier();
      final settings = ChangeNotifier();
      final events = <String>[];
      final lifecycle = WorkspaceHostLifecycle(
        workspaceListenable: workspace,
        settingsListenable: settings,
        requestRefresh: () {
          events.add('refresh');
        },
        handleSettingsChanged: () async {
          events.add('settings');
        },
        restoreWorkspace: () async {
          events.add('restore');
        },
        initializeShellChrome: () {
          events.add('chrome:init');
        },
        disposeShellChrome: () {
          events.add('chrome:dispose');
        },
      );

      lifecycle.initialize();
      await Future<void>.delayed(Duration.zero);
      events.clear();
      lifecycle.dispose();
      workspace.notifyListeners();
      settings.notifyListeners();
      await Future<void>.delayed(Duration.zero);

      expect(events, ['chrome:dispose']);
    });
  });
}
