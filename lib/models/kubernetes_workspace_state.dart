import 'dart:convert';

enum KubernetesTabKind { details, resources }

/// Stored workspace entry for a Kubernetes context tab.
class KubernetesTabState {
  const KubernetesTabState({
    required this.id,
    required this.contextName,
    required this.configPath,
    this.customName,
    this.kind = KubernetesTabKind.details,
  });

  final String id;
  final String contextName;
  final String configPath;
  final String? customName;
  final KubernetesTabKind kind;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'contextName': contextName,
      'configPath': configPath,
      if (customName != null) 'customName': customName,
      'kind': kind.name,
    };
  }

  factory KubernetesTabState.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    final contextName = json['contextName'] as String?;
    final configPath = json['configPath'] as String?;
    if (id == null || contextName == null || configPath == null) {
      throw const FormatException('Missing Kubernetes tab identity');
    }
    final kindName = json['kind'] as String?;
    final kind = KubernetesTabKind.values.firstWhere(
      (value) => value.name == kindName,
      orElse: () => KubernetesTabKind.details,
    );
    return KubernetesTabState(
      id: id,
      contextName: contextName,
      configPath: configPath,
      customName: json['customName'] as String?,
      kind: kind,
    );
  }
}

/// Serialized workspace for the Kubernetes view.
class KubernetesWorkspaceState {
  const KubernetesWorkspaceState({
    required this.tabs,
    this.selectedIndex = 0,
  });

  final List<KubernetesTabState> tabs;
  final int selectedIndex;

  Map<String, dynamic> toJson() {
    return {
      'tabs': tabs.map((tab) => tab.toJson()).toList(),
      'selectedIndex': selectedIndex,
    };
  }

  factory KubernetesWorkspaceState.fromJson(Map<String, dynamic> json) {
    final rawTabs = json['tabs'] as List<dynamic>? ?? const [];
    final tabs = <KubernetesTabState>[];
    for (final entry in rawTabs) {
      if (entry is! Map<String, dynamic>) {
        continue;
      }
      try {
        tabs.add(KubernetesTabState.fromJson(entry));
      } catch (_) {
        // Skip malformed tab entries
      }
    }
    final selected = (json['selectedIndex'] as num?)?.toInt() ?? 0;
    return KubernetesWorkspaceState(tabs: tabs, selectedIndex: selected);
  }

  String get signature => jsonEncode(toJson());
}
