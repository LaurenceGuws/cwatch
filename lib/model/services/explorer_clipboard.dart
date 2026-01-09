import 'package:cwatch/model/models/explorer_context.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/services_infra/ssh/remote_shell_service.dart';

typedef NotifierListener = void Function();

class SimpleNotifier<T> {
  SimpleNotifier(this._value);

  final List<NotifierListener> _listeners = [];
  T _value;

  T get value => _value;

  set value(T next) {
    _value = next;
    final listeners = List<NotifierListener>.from(_listeners);
    for (final listener in listeners) {
      listener();
    }
  }

  void addListener(NotifierListener listener) {
    _listeners.add(listener);
  }

  void removeListener(NotifierListener listener) {
    _listeners.remove(listener);
  }
}

enum ExplorerClipboardOperation { copy, cut }

class ExplorerClipboardCutEvent {
  const ExplorerClipboardCutEvent({
    required this.hostName,
    required this.remotePath,
    required this.contextId,
  });

  final String hostName;
  final String remotePath;
  final String contextId;
}

class ExplorerClipboardEntry {
  const ExplorerClipboardEntry({
    required this.context,
    required this.remotePath,
    required this.displayName,
    required this.isDirectory,
    required this.operation,
    required this.shellService,
  });

  final ExplorerContext context;
  final String remotePath;
  final String displayName;
  final bool isDirectory;
  final ExplorerClipboardOperation operation;
  final RemoteShellService shellService;

  SshHost get host => context.host;
  String get contextId => context.id;
}

class ExplorerClipboard {
  ExplorerClipboard._();

  static final SimpleNotifier<List<ExplorerClipboardEntry>> _notifier =
      SimpleNotifier<List<ExplorerClipboardEntry>>([]);
  static final SimpleNotifier<ExplorerClipboardCutEvent?> _cutNotifier =
      SimpleNotifier<ExplorerClipboardCutEvent?>(null);

  static SimpleNotifier<List<ExplorerClipboardEntry>> get listenable =>
      _notifier;
  static SimpleNotifier<ExplorerClipboardCutEvent?> get cutEvents =>
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
        .where(
          (e) =>
              e.remotePath != entry.remotePath ||
              e.contextId != entry.contextId,
        )
        .toList();
    _cutNotifier.value = ExplorerClipboardCutEvent(
      hostName: entry.host.name,
      remotePath: entry.remotePath,
      contextId: entry.contextId,
    );
  }

  static void notifyCutsCompleted(List<ExplorerClipboardEntry> entries) {
    final currentEntries = _notifier.value;
    final remaining = currentEntries
        .where(
          (e) => entries.every(
            (cut) =>
                cut.remotePath != e.remotePath || cut.contextId != e.contextId,
          ),
        )
        .toList();
    _notifier.value = remaining;
    // Notify for each cut entry
    for (final entry in entries) {
      _cutNotifier.value = ExplorerClipboardCutEvent(
        hostName: entry.host.name,
        remotePath: entry.remotePath,
        contextId: entry.contextId,
      );
    }
  }
}
