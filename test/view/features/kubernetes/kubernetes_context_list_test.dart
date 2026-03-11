import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/services_infra/settings/app_settings_controller.dart';
import 'package:cwatch/model/services_infra/ssh/builtin/builtin_ssh_key_service.dart';
import 'package:cwatch/model/shared/theme/theme_factory.dart';
import 'package:cwatch/view/features/kubernetes/kubernetes_context_list.dart';

void main() {
  testWidgets(
    'KubernetesContextList bootstraps without touching runtime too early',
    (tester) async {
      final settingsController = AppSettingsController();

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeFactory.build(
            settings: settingsController.settings,
            brightness: Brightness.light,
          ),
          home: Scaffold(
            body: KubernetesContextList(
              moduleId: 'k8s',
              settingsController: settingsController,
              keyService: BuiltInSshKeyService(),
              hostsFuture: Future<List<SshHost>>.value(const []),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(KubernetesContextList), findsOneWidget);
    },
  );
}
