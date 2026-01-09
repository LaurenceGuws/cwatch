/// Shared tab state model for persisted workspace tabs across modules.
class TabState {
  const TabState({
    required this.id,
    required this.kind,
    this.title,
    this.label,
    this.hostName,
    this.contextName,
    this.command,
    this.path,
    this.project,
    this.services = const [],
    this.extra,
  });

  final String id;
  final String kind;
  final String? title;
  final String? label;
  final String? hostName;
  final String? contextName;
  final String? command;
  final String? path;
  final String? project;
  final List<String> services;
  final Map<String, dynamic>? extra;

  Map<String, dynamic> toJson() {
    final extras = extra;
    return {
      'id': id,
      'kind': kind,
      if (title != null) 'title': title,
      if (label != null) 'label': label,
      if (hostName != null) 'hostName': hostName,
      if (contextName != null) 'contextName': contextName,
      if (command != null) 'command': command,
      if (path != null) 'path': path,
      if (project != null) 'project': project,
      if (services.isNotEmpty) 'services': services,
      if (extras != null && extras.isNotEmpty) 'extra': extras,
    };
  }

  factory TabState.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    final kind = json['kind'] as String?;
    if (id == null || kind == null) {
      throw const FormatException('Invalid tab state');
    }
    final extra = _extractExtra(json);
    return TabState(
      id: id,
      kind: kind,
      title: json['title'] as String?,
      label: json['label'] as String?,
      hostName: json['hostName'] as String?,
      contextName: json['contextName'] as String?,
      command: json['command'] as String?,
      path: json['path'] as String?,
      project: json['project'] as String?,
      services:
          (json['services'] as List<dynamic>?)?.whereType<String>().toList() ??
          const [],
      extra: extra.isEmpty ? null : extra,
    );
  }

  TabState copyWith({
    String? id,
    String? kind,
    String? title,
    String? label,
    String? hostName,
    String? contextName,
    String? command,
    String? path,
    String? project,
    List<String>? services,
    Map<String, dynamic>? extra,
  }) {
    return TabState(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      title: title ?? this.title,
      label: label ?? this.label,
      hostName: hostName ?? this.hostName,
      contextName: contextName ?? this.contextName,
      command: command ?? this.command,
      path: path ?? this.path,
      project: project ?? this.project,
      services: services ?? this.services,
      extra: extra ?? this.extra,
    );
  }

  static Map<String, dynamic> _extractExtra(Map<String, dynamic> json) {
    final extras = <String, dynamic>{};
    final rawExtra = json['extra'];
    if (rawExtra is Map) {
      for (final entry in rawExtra.entries) {
        if (entry.key is String) {
          extras[entry.key as String] = entry.value;
        }
      }
    }
    void addIfString(String key) {
      final value = json[key];
      if (value is String && value.isNotEmpty) {
        extras.putIfAbsent(key, () => value);
      }
    }

    addIfString('containerId');
    addIfString('containerName');
    return extras;
  }
}

extension TabStateExtras on TabState {
  /// Returns a non-empty string value from [extra] by key, if present.
  String? stringExtra(String key) {
    final extras = extra;
    if (extras == null) return null;
    final value = extras[key];
    if (value is String && value.isNotEmpty) {
      return value;
    }
    return null;
  }
}
