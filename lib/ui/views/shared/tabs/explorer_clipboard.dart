import 'package:flutter/foundation.dart';

import '../../../../models/ssh_host.dart';

enum ExplorerClipboardOperation { copy, cut }

class ExplorerClipboardCutEvent {
  const ExplorerClipboardCutEvent({
    required this.hostName,
    required this.remotePath,
  });

  final String hostName;
  final String remotePath;
}

class ExplorerClipboardEntry {
  const ExplorerClipboardEntry({
    required this.host,
    required this.remotePath,
    required this.displayName,
    required this.isDirectory,
    required this.operation,
  });

  final SshHost host;
  final String remotePath;
  final String displayName;
  final bool isDirectory;
  final ExplorerClipboardOperation operation;
}

class ExplorerClipboard {
  ExplorerClipboard._();

  static final ValueNotifier<List<ExplorerClipboardEntry>> _notifier =
      ValueNotifier<List<ExplorerClipboardEntry>>([]);
  static final ValueNotifier<ExplorerClipboardCutEvent?> _cutNotifier =
      ValueNotifier<ExplorerClipboardCutEvent?>(null);

  static ValueListenable<List<ExplorerClipboardEntry>> get listenable => _notifier;
  static ValueListenable<ExplorerClipboardCutEvent?> get cutEvents =>
      _cutNotifier;
  
  // Backward compatibility: get first entry if single, null if empty
  static ExplorerClipboardEntry? get entry {
    final entries = _notifier.value;
    return entries.isEmpty ? null : entries.first;
  }
  
  // Get all entries
  static List<ExplorerClipboardEntry> get entries => _notifier.value;
  
  // Check if clipboard has content
  static bool get hasEntries => _notifier.value.isNotEmpty;

  static void setEntry(ExplorerClipboardEntry? entry) {
    _notifier.value = entry == null ? [] : [entry];
  }
  
  static void setEntries(List<ExplorerClipboardEntry> entries) {
    _notifier.value = entries;
  }

  static void clear() => setEntries([]);

  static void notifyCutCompleted(ExplorerClipboardEntry entry) {
    final currentEntries = _notifier.value;
    _notifier.value = currentEntries
        .where((e) => e.remotePath != entry.remotePath)
        .toList();
    _cutNotifier.value = ExplorerClipboardCutEvent(
      hostName: entry.host.name,
      remotePath: entry.remotePath,
    );
  }
  
  static void notifyCutsCompleted(List<ExplorerClipboardEntry> entries) {
    final currentEntries = _notifier.value;
    final cutPaths = entries.map((e) => e.remotePath).toSet();
    final remaining = currentEntries
        .where((e) => !cutPaths.contains(e.remotePath))
        .toList();
    _notifier.value = remaining;
    // Notify for each cut entry
    for (final entry in entries) {
      _cutNotifier.value = ExplorerClipboardCutEvent(
        hostName: entry.host.name,
        remotePath: entry.remotePath,
      );
    }
  }
}
