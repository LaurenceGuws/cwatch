class DockerGroupedSection<T> {
  const DockerGroupedSection({
    required this.group,
    required this.items,
    required this.collapsed,
  });

  final String group;
  final List<T> items;
  final bool collapsed;

  String countLabel(String noun) {
    final count = items.length;
    return '$count $noun${count == 1 ? '' : 's'}';
  }
}

class DockerGroupedSectionStateController<T> {
  final Set<String> _collapsed = {};

  List<DockerGroupedSection<T>> buildSections(
    List<T> items,
    String Function(T item) sectionKey,
  ) {
    final grouped = <String, List<T>>{};
    for (final item in items) {
      final key = sectionKey(item);
      grouped.putIfAbsent(key, () => []).add(item);
    }
    final keys = grouped.keys.toList()..sort();
    final sections = [
      for (final key in keys)
        DockerGroupedSection<T>(
          group: key,
          items: grouped[key]!,
          collapsed: _collapsed.contains(key),
        ),
    ];
    _syncCollapsed(sections);
    return sections;
  }

  void toggle(String group) {
    if (_collapsed.contains(group)) {
      _collapsed.remove(group);
    } else {
      _collapsed.add(group);
    }
  }

  bool isCollapsed(String group) => _collapsed.contains(group);

  void _syncCollapsed(List<DockerGroupedSection<T>> sections) {
    if (_collapsed.isEmpty) {
      return;
    }
    final active = sections.map((section) => section.group).toSet();
    _collapsed.removeWhere((group) => !active.contains(group));
  }
}
