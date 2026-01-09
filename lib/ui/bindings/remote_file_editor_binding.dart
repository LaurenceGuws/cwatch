import 'package:flutter/material.dart';

import 'package:cwatch/app/adapters/remote_file_editor_ui_adapter.dart';
import 'package:cwatch/app/controllers/remote_file_editor_controller.dart';
import 'package:cwatch/models/ssh_host.dart';
import 'package:cwatch/services/ssh/remote_shell_service.dart';

class RemoteFileEditorBinding {
  const RemoteFileEditorBinding();

  RemoteFileEditorUiAdapter createUiAdapter({required BuildContext context}) {
    return RemoteFileEditorUiAdapter(context: context);
  }

  RemoteFileEditorController createController({
    required BuildContext context,
    required SshHost host,
    required RemoteShellService shellService,
    required String path,
    Future<void> Function(String content)? onSave,
    RemoteFileEditorUiAdapter? uiAdapter,
  }) {
    final adapter = uiAdapter ?? createUiAdapter(context: context);
    return RemoteFileEditorController(
      host: host,
      shellService: shellService,
      path: path,
      uiAdapter: adapter,
      onSave: onSave,
    );
  }
}
