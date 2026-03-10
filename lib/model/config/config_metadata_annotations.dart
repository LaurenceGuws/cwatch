class ConfigGroup {
  const ConfigGroup({
    required this.key,
    required this.label,
    required this.description,
    this.order,
  });

  final String key;
  final String label;
  final String description;
  final int? order;
}

enum ConfigValueKind {
  string,
  boolean,
  integer,
  doubleValue,
  enumValue,
}

class ConfigField {
  const ConfigField({
    required this.key,
    required this.label,
    required this.description,
    required this.kind,
    this.unit,
    this.defaultValueDoc,
  });

  final String key;
  final String label;
  final String description;
  final ConfigValueKind kind;
  final String? unit;
  final String? defaultValueDoc;
}
