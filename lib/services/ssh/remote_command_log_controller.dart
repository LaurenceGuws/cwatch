import 'dart:collection';

import 'package:flutter/foundation.dart';

import 'remote_command_observer.dart';

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
