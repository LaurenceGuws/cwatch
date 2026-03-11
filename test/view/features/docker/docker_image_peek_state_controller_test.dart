import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/model/models/docker_image.dart';
import 'package:cwatch/view/features/docker/widgets/docker_image_peek_state_controller.dart';

void main() {
  DockerImage image({
    required String id,
    required String repository,
    required String tag,
    required String size,
  }) {
    return DockerImage(
      id: id,
      repository: repository,
      tag: tag,
      size: size,
      createdSince: '1 day ago',
    );
  }

  group('DockerImagePeekStateController', () {
    test('groups images by repository in sorted order', () {
      final controller = DockerImagePeekStateController();
      final rows = controller.buildRows([
        image(id: '2', repository: 'zeta', tag: 'latest', size: '10 MB'),
        image(id: '1', repository: 'alpha', tag: 'stable', size: '20 MB'),
        image(id: '3', repository: '', tag: 'none', size: '5 MB'),
      ]);

      expect(
        rows.map((row) => row.repository).toList(),
        ['<none>', 'alpha', 'zeta'],
      );
      expect(rows[1].displayName, 'alpha');
      expect(rows[0].displayName, '<none>');
    });

    test('calculates aggregate total size across parseable images', () {
      final controller = DockerImagePeekStateController();

      final total = controller.calculateTotalSize([
        image(id: '1', repository: 'a', tag: '1', size: '1 GB'),
        image(id: '2', repository: 'a', tag: '2', size: '512 MB'),
        image(id: '3', repository: 'a', tag: '3', size: '—'),
      ]);

      expect(total, '1.50 GB');
    });

    test('returns dash total size when nothing is parseable', () {
      final controller = DockerImagePeekStateController();

      final total = controller.calculateTotalSize([
        image(id: '1', repository: 'a', tag: '1', size: 'unknown'),
      ]);

      expect(total, '—');
    });

    test('syncExpandedRows disposes stale expansion notifiers', () {
      final controller = DockerImagePeekStateController();
      final stale = controller.expansionFor('stale');
      controller.expansionFor('keep');

      var threwAfterDispose = false;
      controller.syncExpandedRows([
        const DockerImageGroupRow(repository: 'keep', images: []),
      ]);

      try {
        stale.addListener(() {});
      } on FlutterError {
        threwAfterDispose = true;
      }

      expect(threwAfterDispose, isTrue);
      expect(controller.expansionFor('keep').value, isFalse);
    });

    test('group rows expose tag count and display size', () {
      final row = DockerImageGroupRow(
        repository: 'repo',
        images: [
          image(id: '1', repository: 'repo', tag: 'a', size: '20 MB'),
          image(id: '2', repository: 'repo', tag: 'b', size: '30 MB'),
        ],
      );

      expect(row.tagCount, 2);
      expect(row.totalSize, '2 tags');
    });
  });
}
