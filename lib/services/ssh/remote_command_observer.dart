import '../../models/ssh_host.dart';

typedef RemoteCommandObserver = void Function(RemoteCommandDebugEvent event);

class RemoteCommandDebugEvent {
  RemoteCommandDebugEvent({
    required this.host,
    required this.operation,
    required this.command,
    required this.output,
    DateTime? timestamp,
    this.verificationCommand,
    this.verificationOutput,
    this.verificationPassed,
  }) : timestamp = timestamp ?? DateTime.now();

  final SshHost host;
  final String operation;
  final String command;
  final String output;
  final DateTime timestamp;
  final String? verificationCommand;
  final String? verificationOutput;
  final bool? verificationPassed;
}
