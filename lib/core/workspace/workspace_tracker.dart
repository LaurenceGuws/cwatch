/// Tracks persisted/restored workspace signatures to keep tab state saves consistent.
class WorkspaceTracker {
  String? _restoredSignature;
  String? _lastPersistedSignature;
  bool pendingSave = false;

  bool hasRestored(String signature) => _restoredSignature == signature;

  void markRestored(String signature) {
    _restoredSignature = signature;
    _lastPersistedSignature ??= signature;
    pendingSave = false;
  }

  bool shouldPersist(String signature) => _lastPersistedSignature != signature;

  void deferSave() => pendingSave = true;

  void markPersisted(String signature) {
    _lastPersistedSignature = signature;
    _restoredSignature = signature;
    pendingSave = false;
  }
}
