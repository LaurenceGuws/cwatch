import 'package:cwatch/model/config/config_metadata_descriptor.dart';
import 'package:cwatch/model/config/config_metadata_registry.dart';

String buildConfigMetadataMarkdown({
  List<ConfigGroupDescriptor> groups = configMetadataRegistry,
}) {
  final buffer = StringBuffer();
  buffer.writeln('# Config Metadata');
  buffer.writeln();
  for (final group in groups) {
    buffer.writeln('## ${group.label}');
    buffer.writeln();
    buffer.writeln('- Key: `${group.key}`');
    buffer.writeln('- Description: ${group.description}');
    if (group.order != null) {
      buffer.writeln('- Order: ${group.order}');
    }
    buffer.writeln();
    for (final field in group.fields) {
      buffer.writeln('### `${field.key}`');
      buffer.writeln();
      buffer.writeln('- Field: `${field.fieldName}`');
      buffer.writeln('- Label: ${field.label}');
      buffer.writeln('- Type: `${field.kind.name}`');
      if (field.unit != null && field.unit!.isNotEmpty) {
        buffer.writeln('- Unit: `${field.unit}`');
      }
      if (field.defaultValueDoc != null && field.defaultValueDoc!.isNotEmpty) {
        buffer.writeln('- Default: `${field.defaultValueDoc}`');
      }
      buffer.writeln('- Description: ${field.description}');
      buffer.writeln();
    }
  }
  return buffer.toString().trimRight();
}
