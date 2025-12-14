/// Descriptor for a file or directory that can be dragged out to the OS.
class DragLocalItem {
  DragLocalItem({
    required this.localPath,
    required this.displayName,
    required this.isDirectory,
    required this.remotePath,
  });

  /// Path to the staged local payload that can be handed to the OS drag system.
  final String localPath;

  /// Friendly name to present to the OS drop target.
  final String displayName;

  /// True when the payload is a directory.
  final bool isDirectory;

  /// The original remote path (for telemetry or cleanup).
  final String remotePath;
}

/// Result of attempting to start a drag session.
class DragStartResult {
  const DragStartResult({
    required this.started,
    this.error,
  });

  /// True when the platform drag loop was successfully started.
  final bool started;

  /// Optional error detail if the drag could not be started.
  final String? error;
}
