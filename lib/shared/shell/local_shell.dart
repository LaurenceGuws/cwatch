import 'package:flutter/foundation.dart';

/// Supported local shell programs that can power an in-app terminal.
enum SupportedLocalShell {
  bash,
  powershell,
}

/// Defines a shell executable plus launch arguments.
@immutable
class LocalShellDefinition {
  const LocalShellDefinition({
    required this.id,
    required this.executable,
    this.arguments = const [],
    this.description,
  });

  final SupportedLocalShell id;
  final String executable;
  final List<String> arguments;
  final String? description;
}

/// Resolves a shell definition based on the current platform.
class LocalShellResolver {
  const LocalShellResolver();

  LocalShellDefinition forPlatform(TargetPlatform platform) {
    if (kIsWeb) {
      return _bash;
    }
    switch (platform) {
      case TargetPlatform.windows:
        return _powershell;
      default:
        return _bash;
    }
  }

  static const _bash = LocalShellDefinition(
    id: SupportedLocalShell.bash,
    executable: 'bash',
    arguments: ['-l'],
    description: 'Bash login shell',
  );

  static const _powershell = LocalShellDefinition(
    id: SupportedLocalShell.powershell,
    executable: 'powershell',
    arguments: ['-NoLogo', '-NoProfile'],
    description: 'PowerShell without profile scripts',
  );
}
