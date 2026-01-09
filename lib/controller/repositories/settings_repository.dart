import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:cwatch/model/services_infra/logging/app_logger.dart';

class SettingsRepository {
  Future<String?> persistSshConfig({
    required String name,
    required List<int> bytes,
  }) async {
    try {
      final supportDir = await getApplicationSupportDirectory();
      final targetDir = Directory(p.join(supportDir.path, 'ssh_configs'));
      await targetDir.create(recursive: true);
      final fileName = name.isNotEmpty
          ? name
          : 'ssh_config_${DateTime.now().millisecondsSinceEpoch}';
      final target = File(p.join(targetDir.path, fileName));
      await target.writeAsBytes(bytes, flush: true);
      return target.path;
    } catch (error, stackTrace) {
      AppLogger().warn(
        'Failed to persist SSH config $name',
        tag: 'Settings',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }
}
