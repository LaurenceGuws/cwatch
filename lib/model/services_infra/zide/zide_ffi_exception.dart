class ZideFfiException implements Exception {
  const ZideFfiException(this.message);

  final String message;

  @override
  String toString() => 'ZideFfiException: $message';
}
