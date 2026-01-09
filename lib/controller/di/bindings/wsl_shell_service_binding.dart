import 'package:cwatch/model/features/wsl/services/wsl_shell_service.dart';
import 'package:cwatch/model/services_infra/ssh/remote_shell_service.dart';

class WslShellServiceBinding {
  const WslShellServiceBinding();

  RemoteShellService create({required String distroName}) {
    return WslShellService(distroName);
  }
}
