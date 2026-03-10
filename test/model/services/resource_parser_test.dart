import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/model/models/remote_file_entry.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/services/resource_parser.dart';
import 'package:cwatch/model/services_infra/ssh/remote_shell_service.dart';
import 'package:cwatch/model/services_infra/ssh/terminal_session.dart';

void main() {
  group('ResourceParser', () {
    test('collectSnapshot parses CPU, memory, disk, process, and network data', () async {
      final shell = _FakeRemoteShellService(
        output: '''
__CW_CPU__
cpu  100 0 100 800 0 0 0 0 0 0
cpu  160 0 140 840 0 0 0 0 0 0
__CW_MEM__
MemTotal:       2097152 kB
MemAvailable:   1048576 kB
SwapTotal:      1048576 kB
SwapFree:        524288 kB
__CW_LOAD__
1.25 0.75 0.50 1/100 1234
__CW_DISKS__
Filesystem     1B-blocks       Used Use% Mounted on
/dev/sda1      2147483648 1073741824 50% /
__CW_PROC__
PID PPID COMMAND %CPU %MEM
100 1 dart 12.5 10.0
__CW_NET__
Inter-|   Receive                                                |  Transmit
 face |bytes    packets errs drop fifo frame compressed multicast|bytes    packets errs drop fifo colls carrier compressed
    lo: 100 0 0 0 0 0 0 0 100 0 0 0 0 0 0 0
  eth0: 2000 0 0 0 0 0 0 0 4000 0 0 0 0 0 0 0
__CW_DISK_BEFORE__
   8       1 sda1 0 0 1000 0 0 0 2000 0 0 0 0 0
__CW_DISK_AFTER__
   8       1 sda1 0 0 3000 0 0 0 5000 0 0 0 0 0
''',
      );
      final parser = ResourceParser(
        host: _host,
        shellService: shell,
        sampleWindowSeconds: 2,
      );

      final snapshot = await parser.collectSnapshot();

      expect(snapshot.cpuUsage, closeTo(71.4285714286, 0.01));
      expect(snapshot.load1, 1.25);
      expect(snapshot.load5, 0.75);
      expect(snapshot.load15, 0.50);
      expect(snapshot.memoryTotalGb, closeTo(2.0, 0.000001));
      expect(snapshot.memoryUsedGb, closeTo(1.0, 0.000001));
      expect(snapshot.memoryUsedPct, closeTo(50, 0.01));
      expect(snapshot.swapTotalGb, closeTo(1.0, 0.000001));
      expect(snapshot.swapUsedGb, closeTo(0.5, 0.000001));
      expect(snapshot.swapUsedPct, closeTo(50, 0.01));

      expect(snapshot.disks, hasLength(1));
      expect(snapshot.disks.single.filesystem, '/dev/sda1');
      expect(snapshot.disks.single.usedPct, 50);
      expect(snapshot.disks.single.readMbps, closeTo(4.096, 0.000001));
      expect(snapshot.disks.single.writeMbps, closeTo(6.144, 0.000001));
      expect(snapshot.totalDiskIo, closeTo(10.24, 0.000001));

      expect(snapshot.processes, hasLength(1));
      expect(snapshot.processes.single.command, 'dart');
      expect(snapshot.processes.single.cpu, 12.5);
      expect(snapshot.processes.single.memoryPercent, 10.0);
      expect(snapshot.processes.single.memoryBytes, closeTo(214748364.8, 0.1));

      expect(snapshot.netTotals.rxBytes, 2000);
      expect(snapshot.netTotals.txBytes, 4000);
      expect(snapshot.netInMbps, 0);
      expect(snapshot.netOutMbps, 0);
    });

    test('collectSnapshot tolerates malformed and partial sections', () async {
      final shell = _FakeRemoteShellService(
        output: '''
__CW_CPU__
cpu  10 0 10 80
cpu  12 0 12 82
__CW_MEM__
MemTotal: not-a-number
SwapTotal: 0 kB
SwapFree: 0 kB
__CW_LOAD__
not-a-load-line
__CW_DISKS__
Filesystem     1B-blocks       Used Use% Mounted on
bad disk row
/dev/vda1      1000 500 xx% /
__CW_PROC__
PID PPID COMMAND %CPU %MEM
bad process row
200 1 bash nope 5.0
__CW_NET__
  eth0: bad-metrics
  wlan0: 300 0 0 0 0 0 0 0 700 0 0 0 0 0 0 0
__CW_DISK_BEFORE__
missing fields
__CW_DISK_AFTER__
missing fields
''',
      );
      final parser = ResourceParser(
        host: _host,
        shellService: shell,
        sampleWindowSeconds: 1,
      );

      final snapshot = await parser.collectSnapshot();

      expect(snapshot.cpuUsage, closeTo(66.6666666667, 0.01));
      expect(snapshot.memoryTotalGb, 0);
      expect(snapshot.memoryUsedGb, 0);
      expect(snapshot.memoryUsedPct, 0);
      expect(snapshot.swapTotalGb, 0);
      expect(snapshot.swapUsedGb, 0);
      expect(snapshot.swapUsedPct.isNaN, isTrue);
      expect(snapshot.load1, 0);
      expect(snapshot.load5, 0);
      expect(snapshot.load15, 0);

      expect(snapshot.disks, hasLength(1));
      expect(snapshot.disks.single.filesystem, '/dev/vda1');
      expect(snapshot.disks.single.usedPct, 0);
      expect(snapshot.disks.single.readMbps, 0);
      expect(snapshot.disks.single.writeMbps, 0);

      expect(snapshot.processes, hasLength(1));
      expect(snapshot.processes.single.pid, 200);
      expect(snapshot.processes.single.command, 'bash');
      expect(snapshot.processes.single.cpu, 0);
      expect(snapshot.processes.single.memoryPercent, 5.0);
      expect(snapshot.processes.single.memoryBytes, 0);

      expect(snapshot.netTotals.rxBytes, 300);
      expect(snapshot.netTotals.txBytes, 700);
      expect(snapshot.totalDiskIo, 0);
    });

    test('collectSnapshot throws when ssh output is empty', () async {
      final parser = ResourceParser(
        host: _host,
        shellService: _FakeRemoteShellService(output: ''),
        sampleWindowSeconds: 1,
      );

      expect(
        parser.collectSnapshot(),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('No resource data available'))),
      );
    });
  });
}

const _host = SshHost(
  name: 'test-host',
  hostname: 'example.com',
  port: 22,
  available: true,
);

class _FakeRemoteShellService extends RemoteShellService {
  _FakeRemoteShellService({required this.output});

  final String output;

  @override
  Future<String> runCommand(
    SshHost host,
    String command, {
    Duration timeout = const Duration(seconds: 10),
    RunTimeoutHandler? onTimeout,
  }) async => output;

  @override
  Future<List<RemoteFileEntry>> listDirectory(
    SshHost host,
    String path, {
    Duration timeout = const Duration(seconds: 10),
    RunTimeoutHandler? onTimeout,
  }) => throw UnimplementedError();

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
  }) => throw UnimplementedError();

  @override
  Future<String> homeDirectory(
    SshHost host, {
    Duration timeout = const Duration(seconds: 5),
    RunTimeoutHandler? onTimeout,
  }) => throw UnimplementedError();

  @override
  Future<String> readFile(
    SshHost host,
    String path, {
    Duration timeout = const Duration(seconds: 15),
    RunTimeoutHandler? onTimeout,
  }) => throw UnimplementedError();

  @override
  Future<void> writeFile(
    SshHost host,
    String path,
    String contents, {
    Duration timeout = const Duration(seconds: 15),
    RunTimeoutHandler? onTimeout,
  }) => throw UnimplementedError();

  @override
  Future<void> movePath(
    SshHost host,
    String source,
    String destination, {
    Duration timeout = const Duration(seconds: 15),
    RunTimeoutHandler? onTimeout,
  }) => throw UnimplementedError();

  @override
  Future<void> copyPath(
    SshHost host,
    String source,
    String destination, {
    bool recursive = false,
    Duration timeout = const Duration(seconds: 20),
    RunTimeoutHandler? onTimeout,
  }) => throw UnimplementedError();

  @override
  Future<void> deletePath(
    SshHost host,
    String path, {
    Duration timeout = const Duration(seconds: 15),
    RunTimeoutHandler? onTimeout,
  }) => throw UnimplementedError();

  @override
  Future<void> copyBetweenHosts({
    required SshHost sourceHost,
    required String sourcePath,
    required SshHost destinationHost,
    required String destinationPath,
    bool recursive = false,
    Duration timeout = const Duration(minutes: 2),
    RunTimeoutHandler? onTimeout,
  }) => throw UnimplementedError();

  @override
  Future<void> downloadPath({
    required SshHost host,
    required String remotePath,
    required String localDestination,
    bool recursive = false,
    Duration timeout = const Duration(minutes: 2),
    void Function(int bytesTransferred)? onBytes,
    RunTimeoutHandler? onTimeout,
  }) => throw UnimplementedError();

  @override
  Future<void> uploadPath({
    required SshHost host,
    required String localPath,
    required String remoteDestination,
    bool recursive = false,
    Duration timeout = const Duration(minutes: 2),
    void Function(int bytesTransferred)? onBytes,
    RunTimeoutHandler? onTimeout,
  }) => throw UnimplementedError();

  @override
  Future<TerminalSession> createTerminalSession(
    SshHost host, {
    required TerminalSessionOptions options,
    void Function(int exitCode)? onExit,
  }) => throw UnimplementedError();
}
