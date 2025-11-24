import 'dart:convert';

enum DockerTabKind {
  picker,
  contextOverview,
  contextResources,
  hostOverview,
  hostResources,
  command,
  containerExplorer,
  containerShell,
  containerLogs,
  composeLogs,
  containerEditor,
}

class DockerTabState {
  const DockerTabState({
    required this.id,
    required this.kind,
    this.contextName,
    this.hostName,
    this.containerId,
    this.containerName,
    this.command,
    this.title,
    this.path,
    this.project,
    this.services = const [],
  });

  final String id;
  final DockerTabKind kind;
  final String? contextName;
  final String? hostName;
  final String? containerId;
  final String? containerName;
  final String? command;
  final String? title;
  final String? path;
  final String? project;
  final List<String> services;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'kind': kind.name,
      if (contextName != null) 'contextName': contextName,
      if (hostName != null) 'hostName': hostName,
      if (containerId != null) 'containerId': containerId,
      if (containerName != null) 'containerName': containerName,
      if (command != null) 'command': command,
      if (title != null) 'title': title,
      if (path != null) 'path': path,
      if (project != null) 'project': project,
      if (services.isNotEmpty) 'services': services,
    };
  }

  factory DockerTabState.fromJson(Map<String, dynamic> json) {
    final rawKind = json['kind'] as String?;
    final id = json['id'] as String?;
    if (rawKind == null || id == null) {
      throw const FormatException('Invalid docker tab state');
    }
    DockerTabKind? kind;
    for (final value in DockerTabKind.values) {
      if (value.name == rawKind) {
        kind = value;
        break;
      }
    }
    if (kind == null) {
      throw const FormatException('Unknown docker tab kind');
    }
    return DockerTabState(
      id: id,
      kind: kind,
      contextName: json['contextName'] as String?,
      hostName: json['hostName'] as String?,
      containerId: json['containerId'] as String?,
      containerName: json['containerName'] as String?,
      command: json['command'] as String?,
      title: json['title'] as String?,
      path: json['path'] as String?,
      project: json['project'] as String?,
      services:
          (json['services'] as List<dynamic>?)?.whereType<String>().toList() ??
              const [],
    );
  }
}

class DockerWorkspaceState {
  const DockerWorkspaceState({
    required this.tabs,
    this.selectedIndex = 0,
  });

  final List<DockerTabState> tabs;
  final int selectedIndex;

  Map<String, dynamic> toJson() {
    return {
      'tabs': tabs.map((tab) => tab.toJson()).toList(),
      'selectedIndex': selectedIndex,
    };
  }

  factory DockerWorkspaceState.fromJson(Map<String, dynamic> json) {
    final rawTabs = json['tabs'] as List<dynamic>? ?? const [];
    final tabs = <DockerTabState>[];
    for (final entry in rawTabs) {
      if (entry is! Map<String, dynamic>) continue;
      try {
        tabs.add(DockerTabState.fromJson(entry));
      } catch (_) {
        // Skip malformed tabs.
      }
    }
    final selected = (json['selectedIndex'] as num?)?.toInt() ?? 0;
    return DockerWorkspaceState(
      tabs: tabs,
      selectedIndex: selected,
    );
  }

  String get signature => jsonEncode(toJson());
}
