import 'package:flutter/material.dart';

import 'package:cwatch/model/models/kubernetes/kubeconfig_context.dart';
import 'package:cwatch/model/shared/theme/nerd_fonts.dart';
import 'package:cwatch/view/shared/widgets/data_table/structured_data_table.dart';

String kubectlCommandForContext(KubeconfigContext context) {
  return 'kubectl --context=${context.name} --kubeconfig=${context.configPath}';
}

List<StructuredDataMenuAction<KubeconfigContext>> buildKubernetesContextMenuActions({
  required List<KubeconfigContext> selection,
  required void Function(KubeconfigContext context) openContext,
  required Future<void> Function(String text) copyText,
  required Future<void> Function(String configPath) openConfigFile,
}) {
  final singleSelection = selection.length == 1;

  return [
    StructuredDataMenuAction<KubeconfigContext>(
      label: 'Open details',
      icon: NerdIcon.kubernetes.data,
      onSelected: (_, primary) => openContext(primary),
    ),
    StructuredDataMenuAction<KubeconfigContext>(
      label: 'Copy context name',
      icon: NerdIcon.copy.data,
      onSelected: (_, primary) {
        copyText(primary.name);
      },
    ),
    StructuredDataMenuAction<KubeconfigContext>(
      label: 'Copy kubectl command',
      icon: NerdIcon.copy.data,
      onSelected: (_, primary) {
        copyText(kubectlCommandForContext(primary));
      },
    ),
    StructuredDataMenuAction<KubeconfigContext>(
      label: 'Open kubeconfig',
      icon: Icons.open_in_new,
      enabled: singleSelection,
      onSelected: (_, primary) {
        openConfigFile(primary.configPath);
      },
    ),
    StructuredDataMenuAction<KubeconfigContext>(
      label: 'Open details in new tabs',
      icon: NerdIcon.kubernetes.data,
      enabled: selection.length > 1,
      onSelected: (_, _) {
        for (final target in selection) {
          openContext(target);
        }
      },
    ),
  ];
}
