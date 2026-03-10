import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/model/config/config_metadata_registry.dart';
import 'package:cwatch/model/config/config_metadata_target.dart';
import 'package:cwatch/model/models/editor_preferences.dart';
import 'package:cwatch/model/models/explorer_preferences.dart';
import 'package:cwatch/model/models/shell_preferences.dart';
import 'package:cwatch/model/models/terminal_preferences.dart';

void main() {
  test('registry groups are ordered and keyed as expected', () {
    expect(
      configMetadataRegistry.map((group) => group.key).toList(),
      equals(const [
        'shellPreferences',
        'editorPreferences',
        'terminalPreferences',
        'explorerPreferences',
      ]),
    );
    expect(
      configMetadataRegistry.map((group) => group.order).toList(),
      equals(const [10, 20, 30, 40]),
    );
  });

  test('registry covers the first-pass metadata target models exactly', () {
    expect(
      configMetadataRegistry.map((group) => group.modelType).toSet(),
      equals(configMetadataTargetTypes.toSet()),
    );
    expect(
      configMetadataRegistry.map((group) => group.modelType),
      containsAll(const [
        ShellPreferences,
        EditorPreferences,
        TerminalPreferences,
        ExplorerPreferences,
      ]),
    );
  });

  test('group keys are unique and field keys are unique within each group', () {
    final groupKeys = configMetadataRegistry.map((group) => group.key).toList();
    expect(groupKeys.toSet().length, groupKeys.length);

    for (final group in configMetadataRegistry) {
      final fieldKeys = group.fields.map((field) => field.key).toList();
      expect(
        fieldKeys.toSet().length,
        fieldKeys.length,
        reason: 'duplicate field key in ${group.key}',
      );
    }
  });

  test('descriptor records keep the public metadata fields populated', () {
    for (final group in configMetadataRegistry) {
      expect(group.label, isNotEmpty);
      expect(group.description, isNotEmpty);
      expect(group.fields, isNotEmpty);

      for (final field in group.fields) {
        expect(field.fieldName, isNotEmpty);
        expect(field.label, isNotEmpty);
        expect(field.description, isNotEmpty);
      }
    }
  });
}
