import 'remote_path_utils.dart';

class ProcessSshSearchPlan {
  const ProcessSshSearchPlan({
    required this.basePath,
    required this.commandBase,
    required this.escapedQuery,
    required this.nameFlag,
    required this.effectiveTimeoutSeconds,
  });

  final String basePath;
  final String commandBase;
  final String escapedQuery;
  final String nameFlag;
  final int effectiveTimeoutSeconds;
}

class ProcessSshSearchPlanner with RemotePathUtils {
  const ProcessSshSearchPlanner();

  ProcessSshSearchPlan createPlan({
    required String basePath,
    required String query,
    required bool matchCase,
    required bool searchContents,
    required Duration timeout,
  }) {
    final sanitizedPath = sanitizePath(basePath);
    return ProcessSshSearchPlan(
      basePath: sanitizedPath,
      commandBase: "cd '${escapeSingleQuotes(sanitizedPath)}' &&",
      escapedQuery: escapeSingleQuotes(query.trim()),
      nameFlag: matchCase ? '-name' : '-iname',
      effectiveTimeoutSeconds:
          (searchContents ? const Duration(minutes: 2) : timeout).inSeconds,
    );
  }

  String buildPredicate({
    required String typeFlag,
    required bool includeName,
    required ProcessSshSearchPlan plan,
    required bool matchWholeWord,
    required String? includePattern,
    required String? excludePattern,
  }) {
    final pattern = plan.escapedQuery.isEmpty
        ? '*'
        : (matchWholeWord ? plan.escapedQuery : '*${plan.escapedQuery}*');
    final predicates = <String>['-type $typeFlag'];
    if (includeName) {
      predicates.add("${plan.nameFlag} '$pattern'");
    }
    final include = buildPatternClause(
      includePattern,
      nameFlag: plan.nameFlag,
      basePath: plan.basePath,
      allowDeepNameMatch: false,
    );
    if (include.isNotEmpty) {
      predicates.add('-a \\( $include \\)');
    }
    final exclude = buildPatternClause(
      excludePattern,
      nameFlag: plan.nameFlag,
      basePath: plan.basePath,
      allowDeepNameMatch: true,
    );
    if (exclude.isNotEmpty) {
      predicates.add('-a ! \\( $exclude \\)');
    }
    return predicates.join(' ');
  }

  String buildPruneClause(
    String? rawPatterns, {
    required String nameFlag,
    required String basePath,
  }) {
    final patterns = rawPatterns
        ?.split(',')
        .map((pattern) => pattern.trim())
        .where((pattern) => pattern.isNotEmpty)
        .toList();
    if (patterns == null || patterns.isEmpty) {
      return '';
    }
    final clauses = <String>[];
    for (final pattern in patterns) {
      final normalizedPattern = normalizePathPattern(pattern, basePath);
      if (normalizedPattern.contains('/')) {
        final normalized = normalizedPattern;
        final trimmed = normalized.endsWith('/')
            ? normalized.substring(0, normalized.length - 1)
            : normalized;
        final hasGlob =
            trimmed.contains('*') ||
            trimmed.contains('?') ||
            trimmed.contains('[');
        if (hasGlob) {
          clauses.add("-path '${escapeSingleQuotes(trimmed)}'");
        } else {
          clauses.add("-path '${escapeSingleQuotes(trimmed)}'");
          clauses.add("-path '${escapeSingleQuotes('$trimmed/*')}'");
        }
      } else {
        final escaped = escapeSingleQuotes(normalizedPattern);
        clauses.add("$nameFlag '$escaped'");
      }
    }
    return clauses.join(' -o ');
  }

  String buildPatternClause(
    String? rawPatterns, {
    required String nameFlag,
    required String basePath,
    required bool allowDeepNameMatch,
  }) {
    final patterns = rawPatterns
        ?.split(',')
        .map((pattern) => pattern.trim())
        .where((pattern) => pattern.isNotEmpty)
        .toList();
    if (patterns == null || patterns.isEmpty) {
      return '';
    }
    final clauses = <String>[];
    for (final pattern in patterns) {
      final normalizedPattern = normalizePathPattern(pattern, basePath);
      if (normalizedPattern.contains('/')) {
        final normalized = normalizedPattern;
        final hadTrailingSlash = normalized.endsWith('/');
        final trimmed = hadTrailingSlash
            ? normalized.substring(0, normalized.length - 1)
            : normalized;
        final hasGlob =
            trimmed.contains('*') ||
            trimmed.contains('?') ||
            trimmed.contains('[');
        if (hasGlob) {
          clauses.add("-path '${escapeSingleQuotes(trimmed)}'");
        } else if (hadTrailingSlash) {
          clauses.add("-path '${escapeSingleQuotes('$trimmed/*')}'");
        } else {
          clauses.add("-path '${escapeSingleQuotes(trimmed)}'");
          clauses.add("-path '${escapeSingleQuotes('$trimmed/*')}'");
        }
      } else {
        final escaped = escapeSingleQuotes(normalizedPattern);
        if (allowDeepNameMatch) {
          clauses.add("$nameFlag '$escaped'");
          clauses.add("-path './$escaped'");
          clauses.add("-path './$escaped/*'");
          clauses.add("-path './*/$escaped/*'");
        } else {
          clauses.add("-path './$escaped'");
          clauses.add("-path './$escaped/*'");
        }
      }
    }
    return clauses.join(' -o ');
  }

  String normalizePathPattern(String pattern, String basePath) {
    var normalized = pattern.trim();
    if (!normalized.contains('/')) {
      return normalized;
    }
    if (normalized.startsWith(basePath)) {
      normalized = normalized.substring(basePath.length);
    }
    if (normalized.startsWith('/')) {
      normalized = normalized.substring(1);
    }
    if (normalized.isEmpty) {
      return '.';
    }
    if (!normalized.startsWith('./') &&
        !normalized.startsWith('/') &&
        normalized.contains('/')) {
      normalized = './$normalized';
    } else if (normalized.contains('/') && normalized.startsWith('/')) {
      normalized = '.$normalized';
    }
    return normalized;
  }
}
