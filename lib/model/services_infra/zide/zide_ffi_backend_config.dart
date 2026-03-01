import 'dart:io';

import 'package:cwatch/model/models/app_settings.dart';

import 'zide_ffi_exception.dart';

class ZideFfiBackendConfig {
  const ZideFfiBackendConfig({required this.settings});

  final AppSettings settings;

  static const String _backendEnv = 'CWATCH_ZIDE_FFI_BACKEND';
  static const String _terminalLibEnv = 'CWATCH_ZIDE_TERMINAL_LIB';
  static const String _editorLibEnv = 'CWATCH_ZIDE_EDITOR_LIB';

  static const String _backendDefine = String.fromEnvironment(
    _backendEnv,
    defaultValue: '',
  );
  static const String _terminalLibDefine = String.fromEnvironment(
    _terminalLibEnv,
    defaultValue: '',
  );
  static const String _editorLibDefine = String.fromEnvironment(
    _editorLibEnv,
    defaultValue: '',
  );

  bool get enabled {
    if (settings.zideFfiBackendEnabled) {
      return true;
    }
    final envValue = Platform.environment[_backendEnv];
    return _parseBool(envValue) || _parseBool(_backendDefine);
  }

  String resolveTerminalLibraryPath({String? overridePath}) {
    final candidate = _firstNonEmpty([
      overridePath,
      Platform.environment[_terminalLibEnv],
      _terminalLibDefine,
      _workspaceTerminalDefault(),
    ]);
    return _resolveLibraryPath(
      candidate: candidate,
      envVarName: _terminalLibEnv,
      label: 'terminal',
    );
  }

  String resolveEditorLibraryPath({String? overridePath}) {
    final candidate = _firstNonEmpty([
      overridePath,
      Platform.environment[_editorLibEnv],
      _editorLibDefine,
      _workspaceEditorDefault(),
    ]);
    return _resolveLibraryPath(
      candidate: candidate,
      envVarName: _editorLibEnv,
      label: 'editor',
    );
  }

  static bool _parseBool(String? value) {
    final normalized = value?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) {
      return false;
    }
    return normalized == '1' ||
        normalized == 'true' ||
        normalized == 'yes' ||
        normalized == 'on';
  }

  static String? _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  static String _resolveLibraryPath({
    required String? candidate,
    required String envVarName,
    required String label,
  }) {
    if (candidate == null || candidate.isEmpty) {
      throw ZideFfiException(
        'Missing Zide $label FFI library path. Set $envVarName or provide an override path.',
      );
    }

    final file = File(candidate);
    if (!file.existsSync()) {
      throw ZideFfiException(
        'Zide $label library not found at "$candidate". '
        'Set $envVarName to the correct .so path.',
      );
    }
    return file.absolute.path;
  }

  static String? _workspaceTerminalDefault() {
    final home = Platform.environment['HOME']?.trim();
    if (home == null || home.isEmpty) {
      return null;
    }
    return '$home/personal/zide/releases/beta-0.0.1/linux-x86_64/terminal-ffi/libzide-terminal-ffi.so';
  }

  static String? _workspaceEditorDefault() {
    final home = Platform.environment['HOME']?.trim();
    if (home == null || home.isEmpty) {
      return null;
    }
    return '$home/personal/zide/releases/beta-0.0.1/linux-x86_64/editor-ffi/libzide-editor-ffi.so';
  }
}
