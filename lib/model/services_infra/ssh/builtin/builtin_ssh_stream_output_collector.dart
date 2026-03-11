import 'dart:convert';
import 'dart:typed_data';

class BuiltInSshStreamOutputCollector {
  const BuiltInSshStreamOutputCollector();

  Future<void> collect({
    required Stream<Uint8List> stream,
    required StringBuffer buffer,
    void Function(String line)? onLine,
  }) async {
    var remainder = '';
    await stream
        .cast<List<int>>()
        .transform(const Utf8Decoder(allowMalformed: true))
        .forEach((chunk) {
          buffer.write(chunk);
          if (onLine == null) {
            return;
          }
          final combined = remainder + chunk;
          final parts = combined.split('\n');
          remainder = parts.removeLast();
          for (final line in parts) {
            onLine(line);
          }
        });
    if (onLine != null && remainder.isNotEmpty) {
      onLine(remainder);
    }
  }
}
