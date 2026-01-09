import 'package:cwatch/controller/adapters/remote_file_editor_ui_adapter.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/services_infra/ssh/remote_shell_service.dart';

class RemoteFileEditorController {
  RemoteFileEditorController({
    required this.host,
    required this.shellService,
    required this.path,
    required this.uiAdapter,
    this.onSave,
  });

  final SshHost host;
  final RemoteShellService shellService;
  final String path;
  final RemoteFileEditorUiAdapter uiAdapter;
  final Future<void> Function(String content)? onSave;

  Future<String> loadContent({String? initialContent}) {
    if (initialContent != null) {
      return Future<String>.value(initialContent);
    }
    return shellService.readFile(host, path);
  }

  Future<void> saveContent(String content) async {
    if (onSave != null) {
      await onSave!(content);
    } else {
      await shellService.writeFile(host, path, content);
    }
    uiAdapter.showSnackBar('Saved $path');
  }
}
