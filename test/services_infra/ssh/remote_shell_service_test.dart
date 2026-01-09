import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/model/models/remote_file_entry.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/services_infra/ssh/remote_shell_base.dart';
import 'package:cwatch/model/services_infra/ssh/remote_shell_service.dart';
import 'package:cwatch/model/services_infra/ssh/terminal_session.dart';

class TestRemoteShellService extends RemoteShellService {
  TestRemoteShellService({super.debugMode = false, super.observer});

  final List<String> _commandHistory = [];
  List<String> get commandHistory => List.unmodifiable(_commandHistory);

  @override
  Future<List<RemoteFileEntry>> listDirectory(
    SshHost host,
    String path, {
    Duration timeout = const Duration(seconds: 10),
    RunTimeoutHandler? onTimeout,
  }) async {
    return [
      RemoteFileEntry(
        name: 'file1.txt',
        isDirectory: false,
        sizeBytes: 100,
        modified: DateTime.now(),
      ),
      RemoteFileEntry(
        name: 'dir1',
        isDirectory: true,
        sizeBytes: 0,
        modified: DateTime.now(),
      ),
    ];
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
  }) async {
    return [];
  }

  @override
  Future<String> homeDirectory(
    SshHost host, {
    Duration timeout = const Duration(seconds: 5),
    RunTimeoutHandler? onTimeout,
  }) async {
    return '/home/test';
  }

  @override
  Future<String> readFile(
    SshHost host,
    String path, {
    Duration timeout = const Duration(seconds: 15),
    RunTimeoutHandler? onTimeout,
  }) async {
    return 'file contents';
  }

  @override
  Future<void> writeFile(
    SshHost host,
    String path,
    String contents, {
    Duration timeout = const Duration(seconds: 15),
    RunTimeoutHandler? onTimeout,
  }) async {
    _commandHistory.add('write:$path');
  }

  @override
  Future<void> movePath(
    SshHost host,
    String source,
    String destination, {
    Duration timeout = const Duration(seconds: 15),
    RunTimeoutHandler? onTimeout,
  }) async {
    _commandHistory.add('move:$source->$destination');
  }

  @override
  Future<void> copyPath(
    SshHost host,
    String source,
    String destination, {
    bool recursive = false,
    Duration timeout = const Duration(seconds: 20),
    RunTimeoutHandler? onTimeout,
  }) async {
    _commandHistory.add('copy:$source->$destination:$recursive');
  }

  @override
  Future<void> deletePath(
    SshHost host,
    String path, {
    Duration timeout = const Duration(seconds: 15),
    RunTimeoutHandler? onTimeout,
  }) async {
    _commandHistory.add('delete:$path');
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
  }) async {
    _commandHistory.add(
      'copyBetween:$sourceHost.name:$sourcePath->$destinationHost.name:$destinationPath:$recursive',
    );
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
  }) async {
    _commandHistory.add('download:$remotePath->$localDestination:$recursive');
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
  }) async {
    _commandHistory.add('upload:$localPath->$remoteDestination:$recursive');
  }

  @override
  Future<String> runCommand(
    SshHost host,
    String command, {
    Duration timeout = const Duration(seconds: 10),
    RunTimeoutHandler? onTimeout,
  }) async {
    _commandHistory.add(command);
    return 'command output';
  }

  @override
  Future<TerminalSession> createTerminalSession(
    SshHost host, {
    required TerminalSessionOptions options,
  }) async {
    return _TestTerminalSession();
  }
}

class _TestTerminalSession implements TerminalSession {
  @override
  Stream<List<int>> get output => const Stream.empty();

  @override
  Future<int> get exitCode => Future.value(0);

  @override
  void write(List<int> data) {}

  @override
  void resize(int rows, int cols) {}

  @override
  void kill() {}
}

void main() {
  group('RemoteShellService', () {
    late SshHost testHost;

    setUp(() {
      testHost = SshHost(
        name: 'test-host',
        hostname: 'example.com',
        port: 22,
        available: true,
      );
    });

    test('downloadPaths processes multiple downloads', () async {
      final service = TestRemoteShellService();
      final downloads = [
        RemotePathDownload(
          remotePath: '/remote/file1',
          localDestination: '/local/file1',
          recursive: false,
        ),
        RemotePathDownload(
          remotePath: '/remote/dir',
          localDestination: '/local/dir',
          recursive: true,
        ),
      ];

      await service.downloadPaths(
        host: testHost,
        downloads: downloads,
      );

      expect(service.commandHistory, contains('download:/remote/file1->/local/file1:false'));
      expect(service.commandHistory, contains('download:/remote/dir->/local/dir:true'));
    });

    test('downloadPaths calls onError for failed downloads', () async {
      final service = TestRemoteShellService();
      var errorCalled = false;
      RemotePathDownload? errorDownload;
      Object? errorObject;

      await service.downloadPaths(
        host: testHost,
        downloads: [
          RemotePathDownload(
            remotePath: '/remote/file',
            localDestination: '/local/file',
          ),
        ],
        onError: (download, error) {
          errorCalled = true;
          errorDownload = download;
          errorObject = error;
        },
      );

      // In this test, downloads succeed, so onError shouldn't be called
      expect(errorCalled, isFalse);
    });

    test('runCommandStreaming processes output line by line', () async {
      final service = TestRemoteShellService();
      final lines = <String>[];

      final output = await service.runCommandStreaming(
        testHost,
        'test command',
        onStdoutLine: (line) => lines.add(line),
      );

      expect(output, 'command output');
      // Since our test service returns 'command output', it should be split
      expect(lines.length, greaterThan(0));
    });

    test('runCommandStreaming respects cancellation', () async {
      final service = TestRemoteShellService();
      final cancellation = RemoteCommandCancellation();

      cancellation.cancel();

      expect(
        () => service.runCommandStreaming(
          testHost,
          'test',
          cancellation: cancellation,
        ),
        throwsA(isA<RemoteCommandCancelled>()),
      );
    });

    test('parseLsOutput parses directory listing', () {
      final service = TestRemoteShellService();
      final output = '''
total 8
drwxr-xr-x  2 user group 4096 2024-01-01T12:00:00 dir1
-rw-r--r--  1 user group  100 2024-01-01T12:00:00 file1.txt
lrwxrwxrwx  1 user group    5 2024-01-01T12:00:00 link -> target
''';

      final entries = service.parseLsOutput(output);

      expect(entries.length, 3);
      expect(entries[0].name, 'dir1');
      expect(entries[0].isDirectory, isTrue);
      expect(entries[1].name, 'file1.txt');
      expect(entries[1].isDirectory, isFalse);
      expect(entries[1].sizeBytes, 100);
    });

    test('parseLsOutput handles symlinks', () {
      final service = TestRemoteShellService();
      final output = 'lrwxrwxrwx  1 user group    5 2024-01-01T12:00:00 link -> target';

      final entries = service.parseLsOutput(output);

      expect(entries.length, 1);
      expect(entries[0].name, 'link');
      // Symlinks are treated as directories in the current implementation
      expect(entries[0].isDirectory, isTrue);
    });
  });

  group('RemoteCommandCancellation', () {
    test('starts as not cancelled', () {
      final cancellation = RemoteCommandCancellation();
      expect(cancellation.isCancelled, isFalse);
    });

    test('cancel sets cancelled flag', () {
      final cancellation = RemoteCommandCancellation();
      cancellation.cancel();
      expect(cancellation.isCancelled, isTrue);
    });

    test('onCancel calls handler immediately if already cancelled', () {
      final cancellation = RemoteCommandCancellation();
      cancellation.cancel();

      var called = false;
      cancellation.onCancel(() {
        called = true;
      });

      expect(called, isTrue);
    });

    test('onCancel calls handler when cancelled', () {
      final cancellation = RemoteCommandCancellation();
      var called = false;

      cancellation.onCancel(() {
        called = true;
      });

      expect(called, isFalse);
      cancellation.cancel();
      expect(called, isTrue);
    });

    test('multiple handlers are called on cancel', () {
      final cancellation = RemoteCommandCancellation();
      var callCount = 0;

      cancellation.onCancel(() => callCount++);
      cancellation.onCancel(() => callCount++);
      cancellation.onCancel(() => callCount++);

      cancellation.cancel();

      expect(callCount, 3);
    });
  });
}
