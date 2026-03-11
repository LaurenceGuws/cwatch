import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'package:cwatch/controller/controllers/settings_controller.dart';
import 'package:cwatch/model/models/app_settings.dart';
import 'package:cwatch/model/models/kubernetes_backend.dart';
import 'package:cwatch/view/shared/widgets/form_spacer.dart';

class KubernetesSettingsControls extends StatelessWidget {
  const KubernetesSettingsControls({
    super.key,
    required this.settings,
    required this.settingsController,
  });

  final AppSettings settings;
  final SettingsController settingsController;

  @override
  Widget build(BuildContext context) {
    final kubernetes = settings.kubernetesPreferences;
    final configs = kubernetes.configPaths;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Backend'),
        const SizedBox(height: 8),
        DropdownButtonFormField<KubernetesBackend>(
          initialValue: kubernetes.backend,
          items: const [
            DropdownMenuItem(
              value: KubernetesBackend.cli,
              child: Text('CLI (kubectl)'),
            ),
            DropdownMenuItem(value: KubernetesBackend.api, child: Text('API')),
          ],
          onChanged: (value) {
            if (value == null) return;
            settingsController.setKubernetesBackend(value);
          },
        ),
        const FormSpacer(),
        const Text('Kubeconfig Files'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final path in configs)
              InputChip(
                label: Text(p.basename(path)),
                tooltip: path,
                onDeleted: () => _removeConfigPath(path),
              ),
            if (configs.isEmpty)
              const Text('Using default system kubeconfig only.'),
          ],
        ),
        const FormSpacer(),
        ElevatedButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('Add Kubeconfig'),
          onPressed: () => _pickConfigFile(context),
        ),
        const FormSpacer(),
        Text(
          kubernetes.backend == KubernetesBackend.api
              ? 'API backend uses kubeconfig auth (token/certs). exec/auth-provider not supported yet.'
              : 'Using kubectl on this host for Kubernetes data.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Future<void> _pickConfigFile(BuildContext context) async {
    await settingsController.addKubeconfigFile();
  }

  Future<void> _removeConfigPath(String path) async {
    await settingsController.removeKubeconfigPath(path);
  }
}
