import 'package:flutter/material.dart';

import 'package:cwatch/app/adapters/terminal_ui_adapter.dart';
import 'package:cwatch/app/controllers/terminal_session_controller.dart';
import 'package:cwatch/models/ssh_host.dart';
import 'package:cwatch/services/ssh/remote_shell_service.dart';

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
