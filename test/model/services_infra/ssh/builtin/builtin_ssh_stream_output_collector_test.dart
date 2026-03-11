import 'dart:typed_data';

import 'package:cwatch/model/services_infra/ssh/builtin/builtin_ssh_stream_output_collector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('collects output and emits complete lines plus trailing remainder', () async {
    const collector = BuiltInSshStreamOutputCollector();
    final buffer = StringBuffer();
    final lines = <String>[];

    await collector.collect(
      stream: Stream<Uint8List>.fromIterable([
        Uint8List.fromList('alpha\nbr'.codeUnits),
        Uint8List.fromList('avo\ncharlie'.codeUnits),
      ]),
      buffer: buffer,
      onLine: lines.add,
    );

    expect(buffer.toString(), 'alpha\nbravo\ncharlie');
    expect(lines, ['alpha', 'bravo', 'charlie']);
  });

  test('collects output without line callback', () async {
    const collector = BuiltInSshStreamOutputCollector();
    final buffer = StringBuffer();

    await collector.collect(
      stream: Stream<Uint8List>.fromIterable([
        Uint8List.fromList('hello '.codeUnits),
        Uint8List.fromList('world'.codeUnits),
      ]),
      buffer: buffer,
    );

    expect(buffer.toString(), 'hello world');
  });
}
