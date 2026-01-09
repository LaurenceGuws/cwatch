import 'package:cwatch/modules/wsl/services/wsl_shell_service.dart';
import 'package:cwatch/services/ssh/remote_shell_service.dart';

class WslShellServiceBinding {
  const WslShellServiceBinding();

  RemoteShellService create({required String distroName}) {
    return WslShellService(distroName);
  }
}
