import 'package:cwatch/app/controllers/terminal_session_controller.dart';
import 'package:cwatch/models/ssh_host.dart';
import 'package:cwatch/ui/bindings/terminal_tab_binding.dart';
import 'package:cwatch/ui/bindings/wsl_shell_service_binding.dart';

class WslTerminalSessionBinding {
  const WslTerminalSessionBinding();

  TerminalSessionController create({required String distroName}) {
    final shellService = const WslShellServiceBinding().create(
      distroName: distroName,
    );
    const host = SshHost(name: 'wsl', hostname: '', port: 0, available: true);
    return const TerminalTabBinding().createSessionController(
      host: host,
      shellService: shellService,
    );
  }
}
