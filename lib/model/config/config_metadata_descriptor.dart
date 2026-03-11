enum ConfigValueKind { string, boolean, integer, doubleValue, enumValue }

class ConfigFieldDescriptor {
  const ConfigFieldDescriptor({
    required this.key,
    required this.fieldName,
    required this.label,
    required this.description,
    required this.kind,
    this.unit,
    this.defaultValueDoc,
  });

  final String key;
  final String fieldName;
  final String label;
  final String description;
  final ConfigValueKind kind;
  final String? unit;
  final String? defaultValueDoc;
}

class ConfigGroupDescriptor {
  const ConfigGroupDescriptor({
    required this.key,
    required this.label,
    required this.description,
    required this.modelType,
    required this.fields,
    this.order,
  });

  final String key;
  final String label;
  final String description;
  final Type modelType;
  final int? order;
  final List<ConfigFieldDescriptor> fields;
}
