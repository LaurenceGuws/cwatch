import 'dart:convert';

import 'package:cwatch/core/models/tab_state.dart';
import 'package:cwatch/core/models/workspace_state.dart';
import '../services/logging/app_logger.dart';

enum KubernetesTabKind { details, resources }

/// Serialized workspace for the Kubernetes view.
class KubernetesWorkspaceState implements WorkspaceState {
  const KubernetesWorkspaceState({required this.tabs, this.selectedIndex = 0});

  @override
  final List<TabState> tabs;
  @override
  final int selectedIndex;

  @override
  Map<String, dynamic> toJson() {
    return {
      'tabs': tabs.map((tab) => tab.toJson()).toList(),
      'selectedIndex': selectedIndex,
    };
  }

  factory KubernetesWorkspaceState.fromJson(Map<String, dynamic> json) {
    final rawTabs = json['tabs'] as List<dynamic>? ?? const [];
    final tabs = <TabState>[];
    for (final entry in rawTabs) {
      if (entry is! Map<String, dynamic>) continue;
      try {
        tabs.add(TabState.fromJson(entry));
      } catch (error, stackTrace) {
        AppLogger().warn(
          'Failed to parse kubernetes workspace tab',
          tag: 'Workspace',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
    final selected = (json['selectedIndex'] as num?)?.toInt() ?? 0;
    return KubernetesWorkspaceState(tabs: tabs, selectedIndex: selected);
  }

  @override
  String get signature => jsonEncode(toJson());
}
