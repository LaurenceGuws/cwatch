import 'package:cwatch/model/models/persisted_workspaces.dart';
import 'package:cwatch/model/services_infra/settings/workspace_root_controller.dart';
import 'workspace_tracker.dart';

/// Shared helper for persisting and restoring feature workspaces with
/// signature tracking and pending-save handling.
class WorkspacePersistence<T> {
  WorkspacePersistence({
    required this.workspaceRootController,
    required this.readFromRoot,
    required this.writeToRoot,
    required this.signatureOf,
  });

  final WorkspaceRootController workspaceRootController;
  final T? Function(PersistedWorkspaces workspaces) readFromRoot;
  final PersistedWorkspaces Function(PersistedWorkspaces current, T workspace)
  writeToRoot;
  final String Function(T workspace) signatureOf;
  final WorkspaceTracker _tracker = WorkspaceTracker();

  T? read() => readFromRoot(workspaceRootController.workspaces);

  Future<T?> load() async {
    final workspaces = await workspaceRootController.ensureLoaded();
    return readFromRoot(workspaces);
  }

  bool shouldRestore(T workspace) =>
      !_tracker.hasRestored(signatureOf(workspace));

  void markRestored(T workspace) =>
      _tracker.markRestored(signatureOf(workspace));

  Future<void> persist(T workspace) async {
    final signature = signatureOf(workspace);
    if (!_tracker.shouldPersist(signature)) {
      return;
    }
    _tracker.markPersisted(signature);
    await workspaceRootController.update(
      (current) => writeToRoot(current, workspace),
    );
  }

  void persistIfPending(Future<void> Function() persistCallback) {
    if (_tracker.pendingSave) {
      persistCallback();
    }
  }
}
