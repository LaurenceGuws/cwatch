class SearchMatch {
  const SearchMatch({
    required this.start,
    required this.end,
    required this.lineNumber,
    required this.startColumn,
  });

  final int start;
  final int end;
  final int lineNumber; // 1-based
  final int startColumn;

  int get endColumn => startColumn + (end - start);
}
