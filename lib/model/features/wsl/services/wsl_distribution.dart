class WslDistribution {
  const WslDistribution({
    required this.name,
    required this.state,
    required this.version,
    this.isDefault = false,
  });

  final String name;
  final String state;
  final String version;
  final bool isDefault;
}
