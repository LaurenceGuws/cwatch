import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tray_manager/tray_manager.dart';

class TrayIconChoice {
  const TrayIconChoice({
    required this.key,
    required this.assetPath,
    required this.sizeLabel,
  });

  final String key;
  final String assetPath;
  final String sizeLabel;
}

class TrayService {
  TrayService({TrayManager? trayManager})
    : _trayManager = trayManager ?? TrayManager.instance;

  final TrayManager _trayManager;
  bool _initialized = false;
  TrayIconChoice? _activeChoice;

  static const List<TrayIconChoice> iconChoices = [
    TrayIconChoice(
      key: 'icon-32',
      assetPath: 'assets/media/tray/logo_tray_32.png',
      sizeLabel: '32x32',
    ),
    TrayIconChoice(
      key: 'icon-64',
      assetPath: 'assets/media/tray/logo_tray_64.png',
      sizeLabel: '64x64',
    ),
    TrayIconChoice(
      key: 'icon-128',
      assetPath: 'assets/media/tray/logo_tray_128.png',
      sizeLabel: '128x128',
    ),
    TrayIconChoice(
      key: 'icon-256',
      assetPath: 'assets/media/tray/logo_tray_256.png',
      sizeLabel: '256x256',
    ),
    TrayIconChoice(
      key: 'icon-512',
      assetPath: 'assets/media/tray/logo_tray_512.png',
      sizeLabel: '512x512',
    ),
    TrayIconChoice(
      key: 'icon-768',
      assetPath: 'assets/media/tray/logo_tray_768.png',
      sizeLabel: '768x768',
    ),
    TrayIconChoice(
      key: 'icon-1024',
      assetPath: 'assets/media/tray/logo_tray_1024.png',
      sizeLabel: '1024x1024',
    ),
  ];

  bool get isInitialized => _initialized;

  Future<void> ensureInitialized() async {
    if (_initialized) {
      return;
    }
    _activeChoice = _defaultChoice();
    await _setIconChoice(_activeChoice!);
    await _trayManager.setContextMenu(_buildMenu());
    _initialized = true;
  }

  Future<void> destroy() async {
    if (!_initialized) {
      return;
    }
    await _trayManager.destroy();
    _initialized = false;
  }

  Future<void> setIconChoiceByKey(String key) async {
    final choice = iconChoices.firstWhere(
      (candidate) => candidate.key == key,
      orElse: _defaultChoice,
    );
    _activeChoice = choice;
    await _setIconChoice(choice);
  }

  Menu _buildMenu() {
    return Menu(
      items: [
        MenuItem(key: 'show', label: 'Show'),
        MenuItem.submenu(
          label: 'Tray icon',
          submenu: Menu(
            items: iconChoices
                .map(
                  (choice) => MenuItem(
                    key: choice.key,
                    label: choice.sizeLabel,
                    toolTip: choice.sizeLabel,
                  ),
                )
                .toList(),
          ),
        ),
        MenuItem.separator(),
        MenuItem(key: 'quit', label: 'Quit'),
      ],
    );
  }

  Future<void> _setIconChoice(TrayIconChoice choice) async {
    final iconPath = await _writeTrayIcon(choice.assetPath);
    await _trayManager.setIcon(iconPath);
    if (defaultTargetPlatform != TargetPlatform.linux) {
      await _trayManager.setToolTip('cwatch (${choice.sizeLabel})');
    } else {
      await _trayManager.setTitle('cwatch');
    }
  }

  Future<String> _writeTrayIcon(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    final directory = await getApplicationSupportDirectory();
    final file = File('${directory.path}/tray_icon_${assetPath.hashCode}.png');
    await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
    return file.path;
  }

  TrayIconChoice _defaultChoice() {
    if (kIsWeb) {
      return iconChoices[1];
    }
    if (defaultTargetPlatform == TargetPlatform.windows) {
      return iconChoices[4];
    }
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      return iconChoices[3];
    }
    return iconChoices[3];
  }
}
