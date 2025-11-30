import '../../models/app_settings.dart';
import '../../services/settings/app_settings_controller.dart';
import 'workspace_tracker.dart';

/// Shared helper for persisting and restoring feature workspaces with
/// signature tracking and pending-save handling.
class WorkspacePersistence<T> {
  WorkspacePersistence({
    required this.settingsController,
    required this.readFromSettings,
    required this.writeToSettings,
    required this.signatureOf,
  });

  final AppSettingsController settingsController;
  final T? Function(AppSettings settings) readFromSettings;
  final AppSettings Function(AppSettings current, T workspace) writeToSettings;
  final String Function(T workspace) signatureOf;
  final WorkspaceTracker _tracker = WorkspaceTracker();

  T? read() => readFromSettings(settingsController.settings);

  bool shouldRestore(T workspace) =>
      !_tracker.hasRestored(signatureOf(workspace));

  void markRestored(T workspace) =>
      _tracker.markRestored(signatureOf(workspace));

  Future<void> persist(T workspace) async {
    if (!settingsController.isLoaded) {
      _tracker.deferSave();
      return;
    }
    final signature = signatureOf(workspace);
    if (!_tracker.shouldPersist(signature)) {
      return;
    }
    _tracker.markPersisted(signature);
    await settingsController.update(
      (current) => writeToSettings(current, workspace),
    );
  }

  void persistIfPending(Future<void> Function() persistCallback) {
    if (_tracker.pendingSave && settingsController.isLoaded) {
      persistCallback();
    }
  }
}
