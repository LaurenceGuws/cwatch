import 'package:flutter/material.dart';

import 'package:cwatch/controller/adapters/terminal_ui_adapter.dart';
import 'package:cwatch/controller/controllers/terminal_session_controller.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/services_infra/ssh/remote_shell_service.dart';

class TerminalTabBinding {
  const TerminalTabBinding();

  TerminalSessionController createSessionController({
    required SshHost host,
    required RemoteShellService shellService,
  }) {
    return TerminalSessionController(shellService: shellService, host: host);
  }

  TerminalUiAdapter createUiAdapter({required BuildContext context}) {
    return TerminalUiAdapter(context: context);
  }
}
