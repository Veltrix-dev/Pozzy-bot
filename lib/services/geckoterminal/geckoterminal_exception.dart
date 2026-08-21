class GeckoTerminalException implements Exception {
  const GeckoTerminalException(
    this.message, {
    this.statusCode,
    this.isNetworkError = false,
  });

  final String message;
  final int? statusCode;
  final bool isNetworkError;

  @override
  String toString() {
    final status = statusCode == null ? '' : ' HTTP $statusCode';
    return 'GeckoTerminalException$status: $message';
  }
}
