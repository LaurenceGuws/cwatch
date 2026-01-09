import 'package:flutter/material.dart';

import 'package:cwatch/app/adapters/explorer_ui_adapter.dart';
import 'package:cwatch/app/controllers/trash_tab_controller.dart';
import 'package:cwatch/models/explorer_context.dart';
import 'package:cwatch/services/filesystem/explorer_trash_manager.dart';
import 'package:cwatch/services/ssh/builtin/builtin_ssh_key_service.dart';
import 'package:cwatch/services/ssh/remote_shell_service.dart';

class TrashTabBinding {
  const TrashTabBinding();

  TrashTabController create({
    required BuildContext context,
    required ExplorerTrashManager manager,
    required RemoteShellService shellService,
    BuiltInSshKeyService? keyService,
    ExplorerContext? explorerContext,
  }) {
    final uiAdapter = ExplorerUiAdapter(context: context);
    return TrashTabController(
      manager: manager,
      shellService: shellService,
      uiAdapter: uiAdapter,
      keyService: keyService,
      context: explorerContext,
    );
  }
}
