import 'dart:convert';

import 'server_action.dart';

class ServerTabState {
  const ServerTabState({
    required this.id,
    required this.hostName,
    required this.action,
    this.customName,
  });

  final String id;
  final String hostName;
  final ServerAction action;
  final String? customName;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'hostName': hostName,
      'action': action.name,
      if (customName != null) 'customName': customName,
    };
  }

  factory ServerTabState.fromJson(Map<String, dynamic> json) {
    final action = serverActionFromName(json['action'] as String?);
    if (action == null) {
      throw const FormatException('Unknown server tab action');
    }
    final id = json['id'] as String?;
    final hostName = json['hostName'] as String?;
    if (id == null || hostName == null) {
      throw const FormatException('Missing tab identity');
    }
    return ServerTabState(
      id: id,
      hostName: hostName,
      action: action,
      customName: json['customName'] as String?,
    );
  }
}

class ServerWorkspaceState {
  const ServerWorkspaceState({
    required this.tabs,
    this.selectedIndex = 0,
  });

  final List<ServerTabState> tabs;
  final int selectedIndex;

  Map<String, dynamic> toJson() {
    return {
      'tabs': tabs.map((tab) => tab.toJson()).toList(),
      'selectedIndex': selectedIndex,
    };
  }

  factory ServerWorkspaceState.fromJson(Map<String, dynamic> json) {
    final rawTabs = json['tabs'] as List<dynamic>? ?? const [];
    final tabs = <ServerTabState>[];
    for (final entry in rawTabs) {
      if (entry is! Map<String, dynamic>) {
        continue;
      }
      try {
        tabs.add(ServerTabState.fromJson(entry));
      } catch (_) {
        // Skip malformed tab entries
      }
    }
    final selected = (json['selectedIndex'] as num?)?.toInt() ?? 0;
    return ServerWorkspaceState(
      tabs: tabs,
      selectedIndex: selected,
    );
  }

  String get signature => jsonEncode(toJson());
}
