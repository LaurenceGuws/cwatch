import 'dart:convert';

import 'package:cwatch/core/models/tab_state.dart';
import '../services/logging/app_logger.dart';

class ServerWorkspaceState {
  const ServerWorkspaceState({required this.tabs, this.selectedIndex = 0});

  final List<TabState> tabs;
  final int selectedIndex;

  Map<String, dynamic> toJson() {
    return {
      'tabs': tabs.map((tab) => tab.toJson()).toList(),
      'selectedIndex': selectedIndex,
    };
  }

  factory ServerWorkspaceState.fromJson(Map<String, dynamic> json) {
    final rawTabs = json['tabs'] as List<dynamic>? ?? const [];
    final tabs = <TabState>[];
    for (final entry in rawTabs) {
      if (entry is! Map<String, dynamic>) {
        continue;
      }
      try {
        tabs.add(TabState.fromJson(entry));
      } catch (error, stackTrace) {
        AppLogger().warn(
          'Failed to parse server workspace tab',
          tag: 'Workspace',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
    final selected = (json['selectedIndex'] as num?)?.toInt() ?? 0;
    return ServerWorkspaceState(tabs: tabs, selectedIndex: selected);
  }

  String get signature => jsonEncode(toJson());
}
