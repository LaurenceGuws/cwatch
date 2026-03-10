import 'package:cwatch/model/config/config_metadata_annotations.dart';

@ConfigGroup(
  key: 'shellPreferences',
  label: 'Shell Preferences',
  description: 'Window and shell chrome preferences.',
  order: 10,
)
class ShellPreferences {
  const ShellPreferences({
    this.sidebarWidth,
    this.destination,
    this.sidebarCollapsed = false,
    this.sidebarPlacement = 'dynamic',
    this.useSystemDecorations = true,
    this.closeToTray = false,
  });

  @ConfigField(
    key: 'sidebarWidth',
    label: 'Sidebar Width',
    description: 'Preferred sidebar width when the shell sidebar is visible.',
    kind: ConfigValueKind.doubleValue,
    unit: 'px',
  )
  final double? sidebarWidth;
  @ConfigField(
    key: 'destination',
    label: 'Destination',
    description: 'Preferred default shell destination identifier.',
    kind: ConfigValueKind.string,
  )
  final String? destination;
  @ConfigField(
    key: 'sidebarCollapsed',
    label: 'Sidebar Collapsed',
    description: 'Whether the shell sidebar starts collapsed.',
    kind: ConfigValueKind.boolean,
    defaultValueDoc: 'false',
  )
  final bool sidebarCollapsed;
  @ConfigField(
    key: 'sidebarPlacement',
    label: 'Sidebar Placement',
    description: 'Placement mode for the shell sidebar.',
    kind: ConfigValueKind.string,
    defaultValueDoc: 'dynamic',
  )
  final String? sidebarPlacement;
  @ConfigField(
    key: 'useSystemDecorations',
    label: 'Use System Decorations',
    description: 'Whether the shell uses native window decorations.',
    kind: ConfigValueKind.boolean,
    defaultValueDoc: 'true',
  )
  final bool useSystemDecorations;
  @ConfigField(
    key: 'closeToTray',
    label: 'Close To Tray',
    description: 'Whether closing the shell minimizes to the tray instead.',
    kind: ConfigValueKind.boolean,
    defaultValueDoc: 'false',
  )
  final bool closeToTray;

  ShellPreferences copyWith({
    double? sidebarWidth,
    String? destination,
    bool? sidebarCollapsed,
    String? sidebarPlacement,
    bool? useSystemDecorations,
    bool? closeToTray,
  }) {
    return ShellPreferences(
      sidebarWidth: sidebarWidth ?? this.sidebarWidth,
      destination: destination ?? this.destination,
      sidebarCollapsed: sidebarCollapsed ?? this.sidebarCollapsed,
      sidebarPlacement: sidebarPlacement ?? this.sidebarPlacement,
      useSystemDecorations:
          useSystemDecorations ?? this.useSystemDecorations,
      closeToTray: closeToTray ?? this.closeToTray,
    );
  }
}
