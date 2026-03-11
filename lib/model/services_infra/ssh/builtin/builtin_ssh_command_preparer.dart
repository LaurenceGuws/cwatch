import 'package:cwatch/model/models/ssh_host.dart';

import '../remote_shell_base.dart';
import 'builtin_identity_manager.dart';

typedef BuiltInSshNoShellCheck = bool Function(SshHost host);

typedef BuiltInSshWrapErrors<T> = Future<T> Function(
  SshHost host,
  Future<T> Function() action,
);

class BuiltInSshCommandPreparer {
  const BuiltInSshCommandPreparer({
    required this.identityManager,
    required this.isNoShellHost,
    required this.wrapSshErrors,
  });

  final BuiltInSshIdentityManager identityManager;
  final BuiltInSshNoShellCheck isNoShellHost;
  final BuiltInSshWrapErrors wrapSshErrors;

  String prependNoHistory(String command) {
    return 'HISTFILE=/dev/null HISTSIZE=0 HISTFILESIZE=0; $command';
  }

  Future<String> prepareCommand(SshHost host, String command) async {
    if (isNoShellHost(host)) {
      throw NoShellHostException(host);
    }
    final safeCommand = prependNoHistory(command);
    await wrapSshErrors(host, () async {
      await identityManager.ensureDecrypted(host);
    });
    return safeCommand;
  }
}
