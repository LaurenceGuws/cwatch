import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

import 'package:cwatch/model/models/app_settings.dart';
import 'package:cwatch/model/services_infra/logging/app_logger.dart';

class ZideFfiLogConfig {
  ZideFfiLogConfig._();

  static bool _applied = false;

  static void apply({required AppSettings settings}) {
    final env = Platform.environment;
    final global = _sanitize(env['CWATCH_ZIDE_LOG']);
    final console = _sanitize(env['CWATCH_ZIDE_LOG_CONSOLE']) ?? 'none';
    final file = _sanitize(env['CWATCH_ZIDE_LOG_FILE']) ?? 'none';

    _unsetEnv('ZIDE_LOG');
    if (global != null) {
      _setEnv('ZIDE_LOG', global);
    }
    _setEnv('ZIDE_LOG_CONSOLE', console);
    _setEnv('ZIDE_LOG_FILE', file);

    if (!_applied) {
      _applied = true;
      AppLogger().info(
        'zide ffi log config applied global=${global ?? '(unset)'} console=$console file=$file',
        tag: 'ZideFFI',
      );
    } else if (settings.debugMode) {
      AppLogger().debug(
        'zide ffi log config reapplied global=${global ?? '(unset)'} console=$console file=$file',
        tag: 'ZideFFI',
      );
    }
  }

  static String? _sanitize(String? value) {
    if (value == null) {
      return null;
    }
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  static DynamicLibrary _libc() {
    if (Platform.isLinux) {
      return DynamicLibrary.open('libc.so.6');
    }
    if (Platform.isMacOS) {
      return DynamicLibrary.open('/usr/lib/libSystem.B.dylib');
    }
    return DynamicLibrary.process();
  }

  static void _setEnv(String key, String value) {
    final libc = _libc();
    final setenv = libc.lookupFunction<
      Int32 Function(Pointer<Utf8>, Pointer<Utf8>, Int32),
      int Function(Pointer<Utf8>, Pointer<Utf8>, int)
    >('setenv');
    final keyPtr = key.toNativeUtf8();
    final valuePtr = value.toNativeUtf8();
    try {
      setenv(keyPtr, valuePtr, 1);
    } finally {
      calloc.free(keyPtr);
      calloc.free(valuePtr);
    }
  }

  static void _unsetEnv(String key) {
    final libc = _libc();
    final unsetenv = libc.lookupFunction<
      Int32 Function(Pointer<Utf8>),
      int Function(Pointer<Utf8>)
    >('unsetenv');
    final keyPtr = key.toNativeUtf8();
    try {
      unsetenv(keyPtr);
    } finally {
      calloc.free(keyPtr);
    }
  }
}
