import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:toml/toml.dart';

import '../../services/logging/app_logger.dart';
import '../../services/settings/app_settings_controller.dart';
import '../../services/settings/settings_path_provider.dart';
import '../views/shared/tabs/editor/remote_file_editor/editor_theme_utils.dart';

const List<String> _appAccentKeys = [
  'blue-grey',
  'teal',
  'amber',
  'indigo',
  'purple',
  'green',
];

Future<void> applyThemeConfigOverrides(AppSettingsController controller) async {
  final base = await const SettingsPathProvider().configDirectory();
  final appOverrides = await _loadAppThemeOverrides(
    Directory(p.join(base, 'themes', 'app')),
  );
  final editorOverrides = await _loadEditorThemeOverrides(
    Directory(p.join(base, 'themes', 'editor')),
  );
  if (appOverrides == null && editorOverrides == null) {
    return;
  }

  controller.applyOverrides((current) {
    var updated = current;
    if (appOverrides != null) {
      updated = updated.copyWith(
        themeMode: appOverrides.themeMode,
        appThemeKey: appOverrides.appThemeKey,
        appFontFamily: appOverrides.appFontFamily,
      );
    }
    if (editorOverrides != null) {
      updated = updated.copyWith(
        editorThemeLight: editorOverrides.themeKeyLight,
        editorThemeDark: editorOverrides.themeKeyDark,
      );
    }
    return updated;
  });
}

class _AppThemeOverrides {
  const _AppThemeOverrides({
    this.themeMode,
    this.appThemeKey,
    this.appFontFamily,
  });

  final ThemeMode? themeMode;
  final String? appThemeKey;
  final String? appFontFamily;
}

class _EditorThemeOverrides {
  const _EditorThemeOverrides({this.themeKeyLight, this.themeKeyDark});

  final String? themeKeyLight;
  final String? themeKeyDark;
}

Future<_AppThemeOverrides?> _loadAppThemeOverrides(Directory directory) async {
  final file = await _pickFirstToml(directory);
  if (file == null) {
    return null;
  }

  try {
    final data = TomlDocument.parse(await file.readAsString()).toMap();
    final themeMode = _parseThemeMode(data['theme_mode']);
    final appThemeKey = _parseAppAccent(data['app_accent']);
    final appFontFamily = _parseString(data['app_font_family']);
    if (themeMode == null && appThemeKey == null && appFontFamily == null) {
      return null;
    }
    return _AppThemeOverrides(
      themeMode: themeMode,
      appThemeKey: appThemeKey,
      appFontFamily: appFontFamily,
    );
  } catch (error, stackTrace) {
    AppLogger.w(
      'Failed to parse app theme config: ${p.basename(file.path)}',
      tag: 'ThemeConfig',
      error: error,
      stackTrace: stackTrace,
    );
    return null;
  }
}

Future<_EditorThemeOverrides?> _loadEditorThemeOverrides(
  Directory directory,
) async {
  final file = await _pickFirstToml(directory);
  if (file == null) {
    return null;
  }

  try {
    final data = TomlDocument.parse(await file.readAsString()).toMap();
    final themeKey = _parseEditorThemeKey(data['theme_key']);
    final themeKeyLight = _parseEditorThemeKey(data['theme_key_light']);
    final themeKeyDark = _parseEditorThemeKey(data['theme_key_dark']);
    final resolvedLight = themeKeyLight ?? themeKey;
    final resolvedDark = themeKeyDark ?? themeKey;
    if (resolvedLight == null && resolvedDark == null) {
      return null;
    }
    return _EditorThemeOverrides(
      themeKeyLight: resolvedLight,
      themeKeyDark: resolvedDark,
    );
  } catch (error, stackTrace) {
    AppLogger.w(
      'Failed to parse editor theme config: ${p.basename(file.path)}',
      tag: 'ThemeConfig',
      error: error,
      stackTrace: stackTrace,
    );
    return null;
  }
}

Future<File?> _pickFirstToml(Directory directory) async {
  if (!await directory.exists()) {
    return null;
  }
  final entries = await directory.list(followLinks: false).toList();
  final files =
      entries
          .whereType<File>()
          .where((file) => file.path.toLowerCase().endsWith('.toml'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  if (files.isEmpty) {
    return null;
  }
  return files.first;
}

ThemeMode? _parseThemeMode(Object? value) {
  final raw = _parseString(value);
  switch (raw) {
    case 'light':
      return ThemeMode.light;
    case 'dark':
      return ThemeMode.dark;
    case 'system':
      return ThemeMode.system;
    default:
      return null;
  }
}

String? _parseAppAccent(Object? value) {
  final raw = _parseString(value);
  if (raw == null) {
    return null;
  }
  if (_appAccentKeys.contains(raw)) {
    return raw;
  }
  return null;
}

String? _parseEditorThemeKey(Object? value) {
  final raw = _parseString(value);
  if (raw == null) {
    return null;
  }
  final themes = editorThemeOptions();
  if (themes.containsKey(raw)) {
    return raw;
  }
  return null;
}

String? _parseString(Object? value) {
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isNotEmpty) {
      return trimmed;
    }
  }
  return null;
}
