import 'package:cwatch/controller/core/workspace/workspace_tab.dart';
import 'package:cwatch/view/core/tabs/workspace_tab_registry_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const builder = WorkspaceTabRegistryBuilder();

  testWidgets('build creates registry that caches tab widget by id', (
    tester,
  ) async {
    final registry = builder.build(viewKeyPrefix: 'test-tab');
    const tab = WorkspaceTab(
      id: 'one',
      title: 'One',
      label: 'One',
      icon: Icons.looks_one,
      body: SizedBox.shrink(),
    );

    final first = registry.widgetFor(tab, () => const Text('hello'));
    final second = registry.widgetFor(tab, () => const Text('goodbye'));

    expect(identical(first, second), isTrue);
  });
}
