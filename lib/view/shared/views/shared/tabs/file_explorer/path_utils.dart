/// Utility functions for path manipulation
class PathUtils {
  PathUtils._();

  /// Join a base path with a name
  static String joinPath(String base, String name) {
    if (base == '/' || base.isEmpty) {
      return '/$name';
    }
    return '$base/$name';
  }

  /// Get the parent directory of a path
  static String parentDirectory(String path) {
    final normalized = normalizePath(path);
    if (normalized == '/' || !normalized.contains('/')) {
      return '/';
    }
    final index = normalized.lastIndexOf('/');
    if (index <= 0) {
      return '/';
    }
    return normalized.substring(0, index);
  }

  /// Join with base path (alias for joinPath)
  static String joinWithBase(String base, String name) {
    return joinPath(base, name);
  }

  /// Normalize a path by removing redundant separators and resolving '..' and '.'
  /// If input is relative and currentPath is provided, resolves relative to currentPath
  static String normalizePath(String input, {String? currentPath}) {
    if (input.trim().isEmpty) {
      return currentPath ?? '/';
    }
    var path = input.trim();
    if (!path.startsWith('/') && currentPath != null) {
      path = joinPath(currentPath, path);
    }
    final segments = path.split('/');
    final stack = <String>[];
    for (final segment in segments) {
      if (segment.isEmpty || segment == '.') {
        continue;
      }
      if (segment == '..') {
        if (stack.isNotEmpty) {
          stack.removeLast();
        }
      } else {
        stack.add(segment);
      }
    }
    return '/${stack.join('/')}';
  }
}
