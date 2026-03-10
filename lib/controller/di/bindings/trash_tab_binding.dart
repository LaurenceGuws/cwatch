import 'package:flutter/material.dart';

import 'package:cwatch/controller/adapters/explorer_ui_adapter.dart';
import 'package:cwatch/controller/controllers/trash_tab_controller.dart';
import 'package:cwatch/model/models/explorer_context.dart';
import 'package:cwatch/model/services_infra/filesystem/explorer_trash_manager.dart';
import 'package:cwatch/model/services_infra/ssh/remote_shell_service.dart';

class TrashTabBinding {
  const TrashTabBinding();

  TrashTabController create({
    required BuildContext context,
    required ExplorerTrashManager manager,
    required RemoteShellService shellService,
    ExplorerContext? explorerContext,
  }) {
    final uiAdapter = ExplorerUiAdapter(context: context);
    return TrashTabController(
      manager: manager,
      shellService: shellService,
      uiAdapter: uiAdapter,
      context: explorerContext,
    );
  }
}
