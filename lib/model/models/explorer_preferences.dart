class ExplorerPreferences {
  const ExplorerPreferences({
    this.rowHeight = 36,
    this.showBreadcrumbs = true,
  });

  final double rowHeight;
  final bool showBreadcrumbs;

  ExplorerPreferences copyWith({
    double? rowHeight,
    bool? showBreadcrumbs,
  }) {
    return ExplorerPreferences(
      rowHeight: rowHeight ?? this.rowHeight,
      showBreadcrumbs: showBreadcrumbs ?? this.showBreadcrumbs,
    );
  }
}
