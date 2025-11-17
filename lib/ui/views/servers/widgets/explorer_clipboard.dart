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

  static final ValueNotifier<ExplorerClipboardEntry?> _notifier =
      ValueNotifier<ExplorerClipboardEntry?>(null);
  static final ValueNotifier<ExplorerClipboardCutEvent?> _cutNotifier =
      ValueNotifier<ExplorerClipboardCutEvent?>(null);

  static ValueListenable<ExplorerClipboardEntry?> get listenable => _notifier;
  static ValueListenable<ExplorerClipboardCutEvent?> get cutEvents =>
      _cutNotifier;
  static ExplorerClipboardEntry? get entry => _notifier.value;

  static void setEntry(ExplorerClipboardEntry? entry) {
    _notifier.value = entry;
  }

  static void clear() => setEntry(null);

  static void notifyCutCompleted(ExplorerClipboardEntry entry) {
    _notifier.value = null;
    _cutNotifier.value = ExplorerClipboardCutEvent(
      hostName: entry.host.name,
      remotePath: entry.remotePath,
    );
  }
}
