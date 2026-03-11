import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/controller/controllers/kubernetes_context_controller.dart';
import 'package:cwatch/model/models/app_settings.dart';
import 'package:cwatch/model/models/kubernetes/kubeconfig_context.dart';
import 'package:cwatch/model/services_infra/settings/app_settings_controller.dart';
import 'package:cwatch/view/features/kubernetes/kubernetes_context_list_state.dart';

void main() {
  group('KubernetesContextListState', () {
    test('loadContexts populates cache and uses resolved config paths', () async {
      final state = KubernetesContextListState();
      final controller = _FakeKubernetesContextController();
      final settingsController = AppSettingsController();
      settingsController.applyOverrides(
        (_) => const AppSettings(),
      );

      final result = await state.loadContexts(controller, settingsController);

      expect(result, hasLength(2));
      expect(state.cachedContexts, result);
      expect(controller.receivedConfigPaths, const ['/tmp/config-a', '/tmp/config-b']);
    });

    test('resolveContexts falls back to cached contexts when snapshot has no data', () {
      final state = KubernetesContextListState();
      state.cachedContexts = const [_alphaContext];

      final resolved = state.resolveContexts(
        const AsyncSnapshot<List<KubeconfigContext>>.nothing(),
      );

      expect(resolved, const [_alphaContext]);
    });

    test('collapsed state toggles and resets through expand/collapse all', () {
      final state = KubernetesContextListState();
      state.cachedContexts = const [_alphaContext, _betaContext];

      expect(state.isCollapsed('/tmp/config-a'), isFalse);

      state.toggleCollapsed('/tmp/config-a');
      expect(state.isCollapsed('/tmp/config-a'), isTrue);

      state.expandAll();
      expect(state.isCollapsed('/tmp/config-a'), isFalse);

      state.collapseAll();
      expect(state.isCollapsed('/tmp/config-a'), isTrue);
      expect(state.isCollapsed('/tmp/config-b'), isTrue);
    });

    test('updateSelectedRows replaces only keys for the active table', () {
      final state = KubernetesContextListState();
      state.updateSelectedRows(
        const [_alphaContext],
        const [_alphaContext],
        _selectionKey,
      );

      state.updateSelectedRows(
        const [_betaContext],
        const [_betaContext],
        _selectionKey,
      );

      state.updateSelectedRows(
        const [_alphaContext],
        const [],
        _selectionKey,
      );

      expect(state.selectedContextKeys, {_selectionKey(_betaContext)});
    });

    test('toggleListSettings flips overlay visibility', () {
      final state = KubernetesContextListState();

      expect(state.showListSettings, isFalse);
      state.toggleListSettings();
      expect(state.showListSettings, isTrue);
      state.toggleListSettings();
      expect(state.showListSettings, isFalse);
    });
  });
}

String _selectionKey(KubeconfigContext context) =>
    '${context.configPath}:${context.name}';

const _alphaContext = KubeconfigContext(
  name: 'alpha',
  cluster: 'alpha',
  user: 'alpha-user',
  namespace: 'default',
  server: 'https://alpha.example.com',
  configPath: '/tmp/config-a',
  isCurrent: true,
);

const _betaContext = KubeconfigContext(
  name: 'beta',
  cluster: 'beta',
  user: 'beta-user',
  namespace: 'ops',
  server: 'https://beta.example.com',
  configPath: '/tmp/config-b',
  isCurrent: false,
);

class _FakeKubernetesContextController extends KubernetesContextController {
  List<String> receivedConfigPaths = const [];

  @override
  List<String> resolveConfigPaths(AppSettings settings) =>
      const ['/tmp/config-a', '/tmp/config-b'];

  @override
  Future<List<KubeconfigContext>> loadContexts(List<String> configPaths) async {
    receivedConfigPaths = configPaths;
    return const [_alphaContext, _betaContext];
  }
}
