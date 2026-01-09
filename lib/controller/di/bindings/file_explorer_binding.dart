import 'package:flutter/material.dart';

import 'package:cwatch/controller/adapters/explorer_ui_adapter.dart';
import 'package:cwatch/controller/controllers/file_explorer_controller.dart';
import 'package:cwatch/model/models/explorer_context.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/services_infra/filesystem/explorer_trash_manager.dart';
import 'package:cwatch/model/services_infra/settings/app_settings_controller.dart';
import 'package:cwatch/model/services_infra/ssh/remote_shell_service.dart';

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
