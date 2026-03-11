import 'dart:async';

class WorkspaceSettingsSync {
  const WorkspaceSettingsSync();

  Future<void> handleSettingsChanged({
    required bool mounted,
    required String? persistedSignature,
    required String currentSignature,
    required Future<void> Function() restoreWorkspace,
    required Future<void> Function() persistIfPending,
  }) async {
    if (!mounted) {
      return;
    }
    if (persistedSignature != null && persistedSignature != currentSignature) {
      await restoreWorkspace();
    }
    await persistIfPending();
  }

  void handleSettingsChangedAsync({
    required bool mounted,
    required String? persistedSignature,
    required String currentSignature,
    required Future<void> Function() restoreWorkspace,
    required void Function() persistIfPending,
  }) {
    if (!mounted) {
      return;
    }
    if (persistedSignature != null && persistedSignature != currentSignature) {
      unawaited(restoreWorkspace());
    }
    persistIfPending();
  }
}
