import 'dart:collection';

import 'package:flutter/foundation.dart';

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

class RemoteCommandLogController extends ChangeNotifier {
  RemoteCommandLogController({this.maxEntries = 200});

  final int maxEntries;
  final List<RemoteCommandDebugEvent> _events = [];

  UnmodifiableListView<RemoteCommandDebugEvent> get events =>
      UnmodifiableListView(_events);

  bool get isEmpty => _events.isEmpty;

  void add(RemoteCommandDebugEvent event) {
    _events.insert(0, event);
    if (_events.length > maxEntries) {
      _events.removeRange(maxEntries, _events.length);
    }
    notifyListeners();
  }

  void clear() {
    if (_events.isEmpty) {
      return;
    }
    _events.clear();
    notifyListeners();
  }
}
