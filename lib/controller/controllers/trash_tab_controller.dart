import 'package:flutter/foundation.dart';

import 'package:cwatch/model/models/explorer_context.dart';
import 'package:cwatch/model/services_infra/filesystem/explorer_trash_manager.dart';
import 'package:cwatch/model/services_infra/logging/app_logger.dart';
import 'package:cwatch/model/services_infra/ssh/builtin/builtin_remote_shell_service.dart';
import 'package:cwatch/model/services_infra/ssh/remote_shell_service.dart';
import 'package:cwatch/controller/adapters/explorer_ui_adapter.dart';

class TrashTabController extends ChangeNotifier {
  TrashTabController({
    required this.manager,
    required this.shellService,
    required this.uiAdapter,
    this.context,
  });

  final ExplorerTrashManager manager;
  final RemoteShellService shellService;
  final ExplorerUiAdapter uiAdapter;
  final ExplorerContext? context;

  Future<T> runShell<T>(Future<T> Function() action) async {
    try {
      return action();
    } on BuiltInSshAuthenticationFailed catch (error) {
      AppLogger().warn(
        'SSH authentication failed for ${error.hostName}',
        tag: 'Trash',
        error: error,
      );
      uiAdapter.showSnackBar(
        'SSH authentication failed for ${error.hostName}. Check your key configuration in settings.',
      );
      rethrow;
    } on BuiltInSshKeyUnsupportedCipher catch (error) {
      AppLogger().warn(
        'Unsupported cipher for built-in key ${error.keyId}',
        tag: 'Trash',
        error: error,
      );
      final keyLabel = error.keyLabel ?? error.keyId;
      final detail = error.error.message ?? error.error.toString();
      uiAdapter.showSnackBar(
        'Key $keyLabel uses an unsupported cipher ($detail).',
      );
      rethrow;
    }
  }
}
