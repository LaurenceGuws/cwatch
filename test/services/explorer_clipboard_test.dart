import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/model/models/explorer_context.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/services_infra/ssh/remote_shell_service.dart';
import 'package:cwatch/model/services_infra/ssh/terminal_session.dart';
import 'package:cwatch/model/services/explorer_clipboard.dart';

class FakeRemoteShellService extends RemoteShellService {
  FakeRemoteShellService() : super(debugMode: false, observer: null);

  @override
  Future<List<RemoteFileEntry>> listDirectory(
    SshHost host,
    String path, {
    Duration timeout = const Duration(seconds: 10),
    RunTimeoutHandler? onTimeout,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<RemoteFileEntry>> searchPaths(
    SshHost host,
    String basePath,
    String query, {
    String? includePattern,
    String? excludePattern,
    bool matchCase = false,
    bool matchWholeWord = false,
    bool searchContents = false,
    void Function(RemoteFileEntry entry)? onEntry,
    RemoteCommandCancellation? cancellation,
    Duration timeout = const Duration(seconds: 30),
    RunTimeoutHandler? onTimeout,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<String> homeDirectory(
    SshHost host, {
    Duration timeout = const Duration(seconds: 5),
    RunTimeoutHandler? onTimeout,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<String> readFile(
    SshHost host,
    String path, {
    Duration timeout = const Duration(seconds: 15),
    RunTimeoutHandler? onTimeout,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> writeFile(
    SshHost host,
    String path,
    String contents, {
    Duration timeout = const Duration(seconds: 15),
    RunTimeoutHandler? onTimeout,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> movePath(
    SshHost host,
    String source,
    String destination, {
    Duration timeout = const Duration(seconds: 15),
    RunTimeoutHandler? onTimeout,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> copyPath(
    SshHost host,
    String source,
    String destination, {
    bool recursive = false,
    Duration timeout = const Duration(seconds: 20),
    RunTimeoutHandler? onTimeout,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> deletePath(
    SshHost host,
    String path, {
    Duration timeout = const Duration(seconds: 15),
    RunTimeoutHandler? onTimeout,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> copyBetweenHosts({
    required SshHost sourceHost,
    required String sourcePath,
    required SshHost destinationHost,
    required String destinationPath,
    bool recursive = false,
    Duration timeout = const Duration(minutes: 2),
    RunTimeoutHandler? onTimeout,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> downloadPath({
    required SshHost host,
    required String remotePath,
    required String localDestination,
    bool recursive = false,
    Duration timeout = const Duration(minutes: 2),
    void Function(int bytesTransferred)? onBytes,
    RunTimeoutHandler? onTimeout,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> uploadPath({
    required SshHost host,
    required String localPath,
    required String remoteDestination,
    bool recursive = false,
    Duration timeout = const Duration(minutes: 2),
    void Function(int bytesTransferred)? onBytes,
    RunTimeoutHandler? onTimeout,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<String> runCommand(
    SshHost host,
    String command, {
    Duration timeout = const Duration(seconds: 10),
    RunTimeoutHandler? onTimeout,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<TerminalSession> createTerminalSession(
    SshHost host, {
    required TerminalSessionOptions options,
  }) {
    throw UnimplementedError();
  }
}

SshHost _createHost(String name) {
  return SshHost(
    name: name,
    hostname: 'example.com',
    port: 22,
    available: true,
  );
}

ExplorerContext _createContext(SshHost host) {
  return ExplorerContext.server(host);
}

void main() {
  group('ExplorerClipboard', () {
    setUp(() {
      ExplorerClipboard.clear();
    });

    test('starts empty', () {
      expect(ExplorerClipboard.entries, isEmpty);
      expect(ExplorerClipboard.hasEntries, isFalse);
      expect(ExplorerClipboard.entry, isNull);
    });

    test('setEntry sets single entry', () {
      final host = _createHost('host1');
      final context = _createContext(host);
      final shellService = FakeRemoteShellService();
      final entry = ExplorerClipboardEntry(
        context: context,
        remotePath: '/home/file.txt',
        displayName: 'file.txt',
        isDirectory: false,
        operation: ExplorerClipboardOperation.copy,
        shellService: shellService,
      );

      ExplorerClipboard.setEntry(entry);

      expect(ExplorerClipboard.entries.length, 1);
      expect(ExplorerClipboard.entry, entry);
      expect(ExplorerClipboard.hasEntries, isTrue);
      expect(ExplorerClipboard.entries[0].remotePath, '/home/file.txt');
    });

    test('setEntry with null clears clipboard', () {
      final host = _createHost('host1');
      final context = _createContext(host);
      final shellService = FakeRemoteShellService();
      final entry = ExplorerClipboardEntry(
        context: context,
        remotePath: '/home/file.txt',
        displayName: 'file.txt',
        isDirectory: false,
        operation: ExplorerClipboardOperation.copy,
        shellService: shellService,
      );
      ExplorerClipboard.setEntry(entry);

      ExplorerClipboard.setEntry(null);

      expect(ExplorerClipboard.entries, isEmpty);
      expect(ExplorerClipboard.entry, isNull);
    });

    test('setEntries sets multiple entries', () {
      final host = _createHost('host1');
      final context = _createContext(host);
      final shellService = FakeRemoteShellService();
      final entry1 = ExplorerClipboardEntry(
        context: context,
        remotePath: '/home/file1.txt',
        displayName: 'file1.txt',
        isDirectory: false,
        operation: ExplorerClipboardOperation.copy,
        shellService: shellService,
      );
      final entry2 = ExplorerClipboardEntry(
        context: context,
        remotePath: '/home/file2.txt',
        displayName: 'file2.txt',
        isDirectory: false,
        operation: ExplorerClipboardOperation.copy,
        shellService: shellService,
      );

      ExplorerClipboard.setEntries([entry1, entry2]);

      expect(ExplorerClipboard.entries.length, 2);
      expect(ExplorerClipboard.entry, entry1); // First entry for backward compat
      expect(ExplorerClipboard.entries[0].remotePath, '/home/file1.txt');
      expect(ExplorerClipboard.entries[1].remotePath, '/home/file2.txt');
    });

    test('clear removes all entries', () {
      final host = _createHost('host1');
      final context = _createContext(host);
      final shellService = FakeRemoteShellService();
      final entry = ExplorerClipboardEntry(
        context: context,
        remotePath: '/home/file.txt',
        displayName: 'file.txt',
        isDirectory: false,
        operation: ExplorerClipboardOperation.copy,
        shellService: shellService,
      );
      ExplorerClipboard.setEntry(entry);

      ExplorerClipboard.clear();

      expect(ExplorerClipboard.entries, isEmpty);
      expect(ExplorerClipboard.hasEntries, isFalse);
    });

    test('notifyCutCompleted removes entry and notifies cut event', () {
      final host = _createHost('host1');
      final context = _createContext(host);
      final shellService = FakeRemoteShellService();
      final entry = ExplorerClipboardEntry(
        context: context,
        remotePath: '/home/file.txt',
        displayName: 'file.txt',
        isDirectory: false,
        operation: ExplorerClipboardOperation.cut,
        shellService: shellService,
      );
      ExplorerClipboard.setEntry(entry);

      ExplorerClipboardCutEvent? cutEvent;
      ExplorerClipboard.cutEvents.addListener(() {
        cutEvent = ExplorerClipboard.cutEvents.value;
      });

      ExplorerClipboard.notifyCutCompleted(entry);

      expect(ExplorerClipboard.entries, isEmpty);
      expect(cutEvent, isNotNull);
      expect(cutEvent?.hostName, 'host1');
      expect(cutEvent?.remotePath, '/home/file.txt');
      expect(cutEvent?.contextId, context.id);
    });

    test('notifyCutsCompleted removes multiple entries and notifies events', () {
      final host = _createHost('host1');
      final context = _createContext(host);
      final shellService = FakeRemoteShellService();
      final entry1 = ExplorerClipboardEntry(
        context: context,
        remotePath: '/home/file1.txt',
        displayName: 'file1.txt',
        isDirectory: false,
        operation: ExplorerClipboardOperation.cut,
        shellService: shellService,
      );
      final entry2 = ExplorerClipboardEntry(
        context: context,
        remotePath: '/home/file2.txt',
        displayName: 'file2.txt',
        isDirectory: false,
        operation: ExplorerClipboardOperation.cut,
        shellService: shellService,
      );
      final entry3 = ExplorerClipboardEntry(
        context: context,
        remotePath: '/home/file3.txt',
        displayName: 'file3.txt',
        isDirectory: false,
        operation: ExplorerClipboardOperation.copy, // Not cut
        shellService: shellService,
      );
      ExplorerClipboard.setEntries([entry1, entry2, entry3]);

      final cutEvents = <ExplorerClipboardCutEvent>[];
      ExplorerClipboard.cutEvents.addListener(() {
        final event = ExplorerClipboard.cutEvents.value;
        if (event != null) {
          cutEvents.add(event);
        }
      });

      ExplorerClipboard.notifyCutsCompleted([entry1, entry2]);

      expect(ExplorerClipboard.entries.length, 1);
      expect(ExplorerClipboard.entries[0].remotePath, '/home/file3.txt');
      expect(cutEvents.length, 2);
      expect(cutEvents[0].remotePath, '/home/file1.txt');
      expect(cutEvents[1].remotePath, '/home/file2.txt');
    });

    test('listenable notifies listeners on changes', () {
      var notified = false;
      ExplorerClipboard.listenable.addListener(() {
        notified = true;
      });

      final host = _createHost('host1');
      final context = _createContext(host);
      final shellService = FakeRemoteShellService();
      final entry = ExplorerClipboardEntry(
        context: context,
        remotePath: '/home/file.txt',
        displayName: 'file.txt',
        isDirectory: false,
        operation: ExplorerClipboardOperation.copy,
        shellService: shellService,
      );

      ExplorerClipboard.setEntry(entry);

      expect(notified, isTrue);
    });

    test('cutEvents notifies listeners on cut completion', () {
      var notified = false;
      ExplorerClipboard.cutEvents.addListener(() {
        notified = true;
      });

      final host = _createHost('host1');
      final context = _createContext(host);
      final shellService = FakeRemoteShellService();
      final entry = ExplorerClipboardEntry(
        context: context,
        remotePath: '/home/file.txt',
        displayName: 'file.txt',
        isDirectory: false,
        operation: ExplorerClipboardOperation.cut,
        shellService: shellService,
      );
      ExplorerClipboard.setEntry(entry);

      ExplorerClipboard.notifyCutCompleted(entry);

      expect(notified, isTrue);
    });

    test('entry properties are accessible', () {
      final host = _createHost('host1');
      final context = _createContext(host);
      final shellService = FakeRemoteShellService();
      final entry = ExplorerClipboardEntry(
        context: context,
        remotePath: '/home/file.txt',
        displayName: 'file.txt',
        isDirectory: false,
        operation: ExplorerClipboardOperation.copy,
        shellService: shellService,
      );
      ExplorerClipboard.setEntry(entry);

      final retrieved = ExplorerClipboard.entry!;
      expect(retrieved.remotePath, '/home/file.txt');
      expect(retrieved.displayName, 'file.txt');
      expect(retrieved.isDirectory, isFalse);
      expect(retrieved.operation, ExplorerClipboardOperation.copy);
      expect(retrieved.host, host);
      expect(retrieved.contextId, context.id);
    });

    test('handles directory entries', () {
      final host = _createHost('host1');
      final context = _createContext(host);
      final shellService = FakeRemoteShellService();
      final entry = ExplorerClipboardEntry(
        context: context,
        remotePath: '/home/dir',
        displayName: 'dir',
        isDirectory: true,
        operation: ExplorerClipboardOperation.copy,
        shellService: shellService,
      );
      ExplorerClipboard.setEntry(entry);

      expect(ExplorerClipboard.entry?.isDirectory, isTrue);
      expect(ExplorerClipboard.entry?.remotePath, '/home/dir');
    });

    test('handles cut operation', () {
      final host = _createHost('host1');
      final context = _createContext(host);
      final shellService = FakeRemoteShellService();
      final entry = ExplorerClipboardEntry(
        context: context,
        remotePath: '/home/file.txt',
        displayName: 'file.txt',
        isDirectory: false,
        operation: ExplorerClipboardOperation.cut,
        shellService: shellService,
      );
      ExplorerClipboard.setEntry(entry);

      expect(ExplorerClipboard.entry?.operation, ExplorerClipboardOperation.cut);
    });
  });
}
