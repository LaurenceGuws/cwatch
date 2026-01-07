import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:cwatch/models/app_settings.dart';
import 'package:cwatch/services/settings/app_settings_controller.dart';
import 'package:cwatch/shared/widgets/form_spacer.dart';

class KubernetesSettingsControls extends StatelessWidget {
  const KubernetesSettingsControls({
    super.key,
    required this.settings,
    required this.settingsController,
  });

  final AppSettings settings;
  final AppSettingsController settingsController;

  @override
  Widget build(BuildContext context) {
    final configs = settings.kubernetesConfigPaths;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
      ],
    );
  }

  Future<void> _pickConfigFile(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Select kubeconfig file',
      allowMultiple: false,
    );
    final path = result?.files.single.path;
    if (path == null) return;

    final normalized = p.normalize(path);
    final current = settings.kubernetesConfigPaths;
    if (current.contains(normalized)) return;

    await settingsController.update(
      (s) => s.copyWith(kubernetesConfigPaths: [...current, normalized]),
    );
  }

  Future<void> _removeConfigPath(String path) async {
    final current = settings.kubernetesConfigPaths;
    final next = [...current]..remove(path);
    await settingsController.update(
      (s) => s.copyWith(kubernetesConfigPaths: next),
    );
  }
}
