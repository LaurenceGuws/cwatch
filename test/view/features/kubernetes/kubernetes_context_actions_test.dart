import 'package:cwatch/model/models/kubernetes/kubeconfig_context.dart';
import 'package:cwatch/view/features/kubernetes/kubernetes_context_actions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const primary = KubeconfigContext(
    name: 'dev',
    cluster: 'cluster-dev',
    user: 'dev-user',
    namespace: 'default',
    server: 'https://dev.example',
    configPath: '/tmp/dev-kubeconfig',
    isCurrent: true,
  );
  const secondary = KubeconfigContext(
    name: 'prod',
    cluster: 'cluster-prod',
    user: 'prod-user',
    namespace: 'prod',
    server: 'https://prod.example',
    configPath: '/tmp/prod-kubeconfig',
    isCurrent: false,
  );

  test('builds kubectl command for context', () {
    expect(
      kubectlCommandForContext(primary),
      'kubectl --context=dev --kubeconfig=/tmp/dev-kubeconfig',
    );
    expect(
      kubectlCommandForContext(primary, cliCommand: 'brommer-kubectl'),
      'brommer-kubectl --context=dev --kubeconfig=/tmp/dev-kubeconfig',
    );
  });

  test('single-selection actions include copy command and enabled config open', () async {
    String? copied;
    String? openedConfig;
    KubeconfigContext? openedContext;

    final actions = buildKubernetesContextMenuActions(
      selection: const [primary],
      cliCommand: 'brommer-kubectl',
      openContext: (context) => openedContext = context,
      copyText: (text) async => copied = text,
      openConfigFile: (configPath) async => openedConfig = configPath,
    );

    expect(actions.map((action) => action.label), [
      'Open details',
      'Copy context name',
      'Copy kubectl command',
      'Open kubeconfig',
      'Open details in new tabs',
    ]);
    expect(
      actions.firstWhere((action) => action.label == 'Open kubeconfig').enabled,
      isTrue,
    );
    expect(
      actions
          .firstWhere((action) => action.label == 'Open details in new tabs')
          .enabled,
      isFalse,
    );

    actions.firstWhere((action) => action.label == 'Open details').onSelected(
      const [primary],
      primary,
    );
    actions
        .firstWhere((action) => action.label == 'Copy kubectl command')
        .onSelected(const [primary], primary);
    actions.firstWhere((action) => action.label == 'Open kubeconfig').onSelected(
      const [primary],
      primary,
    );

    expect(openedContext, primary);
    expect(
      copied,
      'brommer-kubectl --context=dev --kubeconfig=/tmp/dev-kubeconfig',
    );
    expect(openedConfig, '/tmp/dev-kubeconfig');
  });

  test('multi-selection action opens each context in new tabs', () {
    final opened = <KubeconfigContext>[];
    final actions = buildKubernetesContextMenuActions(
      selection: const [primary, secondary],
      cliCommand: 'brommer-kubectl',
      openContext: opened.add,
      copyText: (_) async {},
      openConfigFile: (_) async {},
    );

    final action = actions.firstWhere(
      (candidate) => candidate.label == 'Open details in new tabs',
    );

    expect(action.enabled, isTrue);
    expect(
      actions.firstWhere((candidate) => candidate.label == 'Open kubeconfig').enabled,
      isFalse,
    );

    action.onSelected(const [primary, secondary], primary);

    expect(opened, [primary, secondary]);
  });
}
