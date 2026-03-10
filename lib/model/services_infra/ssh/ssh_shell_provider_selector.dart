import 'package:cwatch/model/models/app_settings.dart';
import 'package:cwatch/model/services_infra/ssh/ssh_shell_provider_request.dart';

class SshShellProviderSelector {
  const SshShellProviderSelector();

  SshShellProviderRequest select({
    required AppSettings settings,
    Duration? connectTimeout,
  }) {
    return SshShellProviderRequest(
      backend: settings.sshPreferences.clientBackend,
      debugMode: settings.debugMode,
      bindingsSignature: _bindingsSignature(settings),
      connectTimeout: connectTimeout,
    );
  }

  String settingsSignature(AppSettings settings) {
    return select(settings: settings).settingsSignature;
  }

  String _bindingsSignature(AppSettings settings) {
    final bindings = settings.sshPreferences.builtinHostKeyBindings.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return bindings.map((entry) => '${entry.key}:${entry.value}').join(',');
  }
}
