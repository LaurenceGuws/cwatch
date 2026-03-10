import 'package:cwatch/model/core/models/tab_state.dart';
import 'package:cwatch/model/models/server_action.dart';
import 'package:cwatch/model/models/ssh_host.dart';

class ServerTabData {
  const ServerTabData({
    required this.host,
    required this.action,
    required this.persistedState,
  });

  final SshHost host;
  final ServerAction action;
  final TabState persistedState;
}
