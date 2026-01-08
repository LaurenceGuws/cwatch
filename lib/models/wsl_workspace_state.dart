import 'dart:convert';

import 'package:cwatch/core/models/tab_state.dart';
import 'package:cwatch/core/models/workspace_state.dart';
import '../services/logging/app_logger.dart';

enum WslTabKind {
  distroList,
  terminal,
}

class WslTabState {
  const WslTabState({
    required this.id,
    required this.kind,
    this.distroName,
    this.title,
  });

  final String id;
  final WslTabKind kind;
  final String? distroName;
  final String? title;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'kind': kind.name,
      if (distroName != null) 'distroName': distroName,
      if (title != null) 'title': title,
    };
  }

  factory WslTabState.fromJson(Map<String, dynamic> json) {
    final rawKind = json['kind'] as String?;
    final id = json['id'] as String?;
    if (rawKind == null || id == null) {
      throw const FormatException('Invalid wsl tab state');
    }
    WslTabKind? kind;
    for (final value in WslTabKind.values) {
      if (value.name == rawKind) {
        kind = value;
        break;
      }
    }
    if (kind == null) {
      throw const FormatException('Unknown wsl tab kind');
    }
    return WslTabState(
      id: id,
      kind: kind,
      distroName: json['distroName'] as String?,
      title: json['title'] as String?,
    );
  }
}

class WslWorkspaceState implements WorkspaceState {
  const WslWorkspaceState({required this.tabs, this.selectedIndex = 0});

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

  factory WslWorkspaceState.fromJson(Map<String, dynamic> json) {
    final rawTabs = json['tabs'] as List<dynamic>? ?? const [];
    final tabs = <TabState>[];
    for (final entry in rawTabs) {
      if (entry is! Map<String, dynamic>) continue;
      try {
        tabs.add(TabState.fromJson(entry));
      } catch (error, stackTrace) {
        AppLogger().warn(
          'Failed to parse wsl workspace tab',
          tag: 'Workspace',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
    final selected = (json['selectedIndex'] as num?)?.toInt() ?? 0;
    return WslWorkspaceState(tabs: tabs, selectedIndex: selected);
  }

  @override
  String get signature => jsonEncode(toJson());
}
