import 'dart:convert';

import 'package:cwatch/core/models/tab_state.dart';

enum KubernetesTabKind { details, resources }

/// Serialized workspace for the Kubernetes view.
class KubernetesWorkspaceState {
  const KubernetesWorkspaceState({required this.tabs, this.selectedIndex = 0});

  final List<TabState> tabs;
  final int selectedIndex;

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
      } catch (_) {
        // Skip malformed tab entries
      }
    }
    final selected = (json['selectedIndex'] as num?)?.toInt() ?? 0;
    return KubernetesWorkspaceState(tabs: tabs, selectedIndex: selected);
  }

  String get signature => jsonEncode(toJson());
}
