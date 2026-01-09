import 'package:flutter/material.dart';

import '../../app/adapters/explorer_ui_adapter.dart';
import '../../app/controllers/file_explorer_controller.dart';
import '../../models/explorer_context.dart';
import '../../models/ssh_host.dart';
import '../../services/filesystem/explorer_trash_manager.dart';
import '../../services/settings/app_settings_controller.dart';
import '../../services/ssh/remote_shell_service.dart';

class FileExplorerBinding {
  const FileExplorerBinding();

  FileExplorerController create({
    required BuildContext context,
    required SshHost host,
    required ExplorerContext explorerContext,
    required RemoteShellService shellService,
    required AppSettingsController settingsController,
    required ExplorerTrashManager trashManager,
    String? initialPath,
    ValueChanged<String>? onPathChanged,
    Future<void> Function(String path, String initialContent)? onOpenEditorTab,
  }) {
    return FileExplorerController(
      host: host,
      explorerContext: explorerContext,
      shellService: shellService,
      settingsController: settingsController,
      trashManager: trashManager,
      uiAdapter: ExplorerUiAdapter(context: context),
      initialPath: initialPath,
      onPathChanged: onPathChanged,
      onOpenEditorTab: onOpenEditorTab,
    );
  }
}
