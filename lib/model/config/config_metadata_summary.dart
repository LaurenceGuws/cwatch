import 'package:cwatch/model/config/config_metadata_descriptor.dart';
import 'package:cwatch/model/config/config_metadata_registry.dart';

String buildConfigMetadataSummary({
  List<ConfigGroupDescriptor> groups = configMetadataRegistry,
}) {
  final buffer = StringBuffer();
  for (final group in groups) {
    buffer.writeln('[${group.key}] ${group.label}');
    buffer.writeln(group.description);
    for (final field in group.fields) {
      buffer.write('- ${field.key} (${field.fieldName}): ${field.label}');
      buffer.write(' [${field.kind.name}]');
      if (field.unit != null && field.unit!.isNotEmpty) {
        buffer.write(' unit=${field.unit}');
      }
      if (field.defaultValueDoc != null && field.defaultValueDoc!.isNotEmpty) {
        buffer.write(' default=${field.defaultValueDoc}');
      }
      buffer.writeln();
      buffer.writeln('  ${field.description}');
    }
    buffer.writeln();
  }
  return buffer.toString().trimRight();
}
