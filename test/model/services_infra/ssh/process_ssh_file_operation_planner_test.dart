import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/model/services_infra/ssh/process_ssh_file_operation_planner.dart';

void main() {
  const planner = ProcessSshFileOperationPlanner();

  test('normalizes parent directories through remote path rules', () {
    expect(planner.normalize('/tmp/../var/log'), '/tmp/../var/log');
    expect(planner.parentDirectory('/var/log/app.txt'), '/var/log');
  });

  test('builds read and exists-check commands with escaped paths', () {
    expect(
      planner.readFileCommand("/tmp/it's.txt"),
      "cat '/tmp/it'\\''s.txt'",
    );
    expect(
      planner.existsCheckCommand("/tmp/it's.txt"),
      "[ -e '/tmp/it'\\''s.txt' ] && echo 'EXISTS' || echo 'MISSING'",
    );
  });

  test('builds write command with delimiter and encoded contents', () {
    expect(
      planner.writeFileCommand(
        path: '/tmp/file.txt',
        encodedContents: 'YWJj',
        delimiter: 'XYZ',
      ),
      "base64 -d > '/tmp/file.txt' <<'XYZ'\nYWJj\nXYZ",
    );
  });

  test('builds move, copy, delete, and mkdir commands', () {
    expect(
      planner.movePathCommand('/tmp/a', '/tmp/b'),
      "mv '/tmp/a' '/tmp/b'",
    );
    expect(
      planner.copyPathCommand('/tmp/a', '/tmp/b', recursive: false),
      "cp '/tmp/a' '/tmp/b'",
    );
    expect(
      planner.copyPathCommand('/tmp/a', '/tmp/b', recursive: true),
      "cp -R '/tmp/a' '/tmp/b'",
    );
    expect(planner.deletePathCommand('/tmp/a'), "rm -rf '/tmp/a'");
    expect(planner.ensureDirectoryCommand('/tmp/a'), "mkdir -p '/tmp/a'");
  });
}
