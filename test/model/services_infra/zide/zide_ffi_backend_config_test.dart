import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/model/models/app_settings.dart';
import 'package:cwatch/model/services_infra/zide/zide_ffi_backend_config.dart';
import 'package:cwatch/model/services_infra/zide/zide_ffi_exception.dart';

void main() {
  test('enabled true when setting is enabled', () {
    const settings = AppSettings(zideFfiBackendEnabled: true);
    final config = ZideFfiBackendConfig(settings: settings);
    expect(config.enabled, isTrue);
  });

  test('resolve paths from explicit override', () async {
    final tempDir = await Directory.systemTemp.createTemp('zide-config-test');
    try {
      final terminalFile = File('${tempDir.path}/terminal.so');
      final editorFile = File('${tempDir.path}/editor.so');
      await terminalFile.writeAsBytes(const [0]);
      await editorFile.writeAsBytes(const [0]);

      const settings = AppSettings();
      final config = ZideFfiBackendConfig(settings: settings);

      expect(
        config.resolveTerminalLibraryPath(overridePath: terminalFile.path),
        terminalFile.absolute.path,
      );
      expect(
        config.resolveEditorLibraryPath(overridePath: editorFile.path),
        editorFile.absolute.path,
      );
    } finally {
      await tempDir.delete(recursive: true);
    }
  });

  test('clear error for missing library file', () {
    const settings = AppSettings();
    final config = ZideFfiBackendConfig(settings: settings);

    expect(
      () => config.resolveTerminalLibraryPath(
        overridePath: '/definitely/missing/libzide-terminal-ffi.so',
      ),
      throwsA(
        isA<ZideFfiException>().having(
          (error) => error.message,
          'message',
          contains('library not found'),
        ),
      ),
    );
  });
}
