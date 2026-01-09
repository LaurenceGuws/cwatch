import 'dart:math';

mixin RemotePathUtils {
  String sanitizePath(String path) {
    if (path.isEmpty) {
      return '/';
    }
    if (path.startsWith('/')) {
      return path;
    }
    return '/$path';
  }

  String escapeSingleQuotes(String input) => input.replaceAll("'", r"'\''");

  String singleQuoteForShell(String input) {
    return "'${input.replaceAll("'", "'\\''")}'";
  }

  String dirnameFromPath(String path) {
    final normalized = sanitizePath(path);
    final index = normalized.lastIndexOf('/');
    if (index <= 0) {
      return '/';
    }
    return normalized.substring(0, index);
  }

  String randomDelimiter({int length = 12}) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random();
    return List.generate(
      length,
      (index) => chars[rand.nextInt(chars.length)],
    ).join();
  }
}
