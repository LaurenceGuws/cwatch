class ShellPreferences {
  const ShellPreferences({
    this.sidebarWidth,
    this.destination,
    this.sidebarCollapsed = false,
    this.sidebarPlacement = 'dynamic',
    this.useSystemDecorations = true,
    this.closeToTray = false,
  });

  final double? sidebarWidth;
  final String? destination;
  final bool sidebarCollapsed;
  final String? sidebarPlacement;
  final bool useSystemDecorations;
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
