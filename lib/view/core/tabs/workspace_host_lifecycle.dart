import 'dart:async';

import 'package:flutter/foundation.dart';

class WorkspaceHostLifecycle {
  WorkspaceHostLifecycle({
    required Listenable workspaceListenable,
    required Listenable settingsListenable,
    required VoidCallback requestRefresh,
    required Future<void> Function() handleSettingsChanged,
    required Future<void> Function() restoreWorkspace,
    required VoidCallback initializeShellChrome,
    required VoidCallback disposeShellChrome,
  }) : _workspaceListenable = workspaceListenable,
       _settingsListenable = settingsListenable,
       _requestRefresh = requestRefresh,
       _handleSettingsChanged = handleSettingsChanged,
       _restoreWorkspace = restoreWorkspace,
       _initializeShellChrome = initializeShellChrome,
       _disposeShellChrome = disposeShellChrome;

  final Listenable _workspaceListenable;
  final Listenable _settingsListenable;
  final VoidCallback _requestRefresh;
  final Future<void> Function() _handleSettingsChanged;
  final Future<void> Function() _restoreWorkspace;
  final VoidCallback _initializeShellChrome;
  final VoidCallback _disposeShellChrome;

  late final VoidCallback _tabsListener = _requestRefresh;
  late final VoidCallback _settingsListener = _onSettingsChanged;

  void initialize() {
    _workspaceListenable.addListener(_tabsListener);
    _settingsListenable.addListener(_settingsListener);
    _initializeShellChrome();
    unawaited(_restoreWorkspace());
  }

  void dispose() {
    _workspaceListenable.removeListener(_tabsListener);
    _settingsListenable.removeListener(_settingsListener);
    _disposeShellChrome();
  }

  void _onSettingsChanged() {
    unawaited(_handleSettingsChanged());
  }
}
