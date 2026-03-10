import 'package:cwatch/model/config/config_metadata_annotations.dart';

@ConfigGroup(
  key: 'explorerPreferences',
  label: 'Explorer Preferences',
  description: 'Shared explorer layout and navigation preferences.',
  order: 40,
)
class ExplorerPreferences {
  const ExplorerPreferences({
    this.rowHeight = 36,
    this.showBreadcrumbs = true,
  });

  @ConfigField(
    key: 'rowHeight',
    label: 'Row Height',
    description: 'Preferred explorer row height.',
    kind: ConfigValueKind.doubleValue,
    unit: 'px',
    defaultValueDoc: '36',
  )
  final double rowHeight;
  @ConfigField(
    key: 'showBreadcrumbs',
    label: 'Show Breadcrumbs',
    description: 'Whether the explorer shows breadcrumb navigation.',
    kind: ConfigValueKind.boolean,
    defaultValueDoc: 'true',
  )
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
