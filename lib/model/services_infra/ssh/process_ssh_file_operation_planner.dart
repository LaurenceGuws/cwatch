import 'remote_path_utils.dart';

class ProcessSshFileOperationPlanner with RemotePathUtils {
  const ProcessSshFileOperationPlanner();

  String normalize(String path) => sanitizePath(path);

  String parentDirectory(String path) => dirnameFromPath(sanitizePath(path));

  String readFileCommand(String path) {
    final normalized = sanitizePath(path);
    return "cat '${escapeSingleQuotes(normalized)}'";
  }

  String writeFileCommand({
    required String path,
    required String encodedContents,
    required String delimiter,
  }) {
    final normalized = sanitizePath(path);
    return "base64 -d > '${escapeSingleQuotes(normalized)}' <<'$delimiter'\n$encodedContents\n$delimiter";
  }

  String movePathCommand(String source, String destination) {
    final normalizedSource = sanitizePath(source);
    final normalizedDest = sanitizePath(destination);
    return "mv '${escapeSingleQuotes(normalizedSource)}' '${escapeSingleQuotes(normalizedDest)}'";
  }

  String copyPathCommand(
    String source,
    String destination, {
    required bool recursive,
  }) {
    final normalizedSource = sanitizePath(source);
    final normalizedDest = sanitizePath(destination);
    final flag = recursive ? '-R ' : '';
    return "cp $flag'${escapeSingleQuotes(normalizedSource)}' '${escapeSingleQuotes(normalizedDest)}'";
  }

  String deletePathCommand(String path) {
    final normalized = sanitizePath(path);
    return "rm -rf '${escapeSingleQuotes(normalized)}'";
  }

  String ensureDirectoryCommand(String directory) {
    final normalized = sanitizePath(directory);
    return "mkdir -p '${escapeSingleQuotes(normalized)}'";
  }

  String existsCheckCommand(String path) {
    final normalized = sanitizePath(path);
    return "[ -e '${escapeSingleQuotes(normalized)}' ] && echo 'EXISTS' || echo 'MISSING'";
  }
}
