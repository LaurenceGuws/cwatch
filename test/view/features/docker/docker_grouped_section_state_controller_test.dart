import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/view/features/docker/widgets/docker_grouped_section_state_controller.dart';

void main() {
  group('DockerGroupedSectionStateController', () {
    test('builds sorted grouped sections', () {
      final controller = DockerGroupedSectionStateController<String>();

      final sections = controller.buildSections(
        ['beta-net', 'alpha-net', 'alpha-db'],
        (name) => name.split('-').first,
      );

      expect(sections.map((section) => section.group).toList(), [
        'alpha',
        'beta',
      ]);
      expect(sections[0].items, ['alpha-net', 'alpha-db']);
    });

    test('toggle updates collapsed state', () {
      final controller = DockerGroupedSectionStateController<String>();

      controller.toggle('alpha');
      expect(controller.isCollapsed('alpha'), isTrue);

      controller.toggle('alpha');
      expect(controller.isCollapsed('alpha'), isFalse);
    });

    test('stale collapsed groups are dropped when sections change', () {
      final controller = DockerGroupedSectionStateController<String>();
      controller.toggle('stale');
      controller.toggle('keep');

      final sections = controller.buildSections(
        ['keep-item'],
        (_) => 'keep',
      );

      expect(sections.single.collapsed, isTrue);
      expect(controller.isCollapsed('stale'), isFalse);
      expect(controller.isCollapsed('keep'), isTrue);
    });

    test('countLabel pluralizes correctly', () {
      const single = DockerGroupedSection<String>(
        group: 'one',
        items: ['a'],
        collapsed: false,
      );
      const multi = DockerGroupedSection<String>(
        group: 'many',
        items: ['a', 'b'],
        collapsed: false,
      );

      expect(single.countLabel('network'), '1 network');
      expect(multi.countLabel('volume'), '2 volumes');
    });
  });
}
