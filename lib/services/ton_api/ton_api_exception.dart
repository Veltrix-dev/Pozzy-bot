enum TonApiErrorKind {
  configuration,
  invalidInput,
  insufficientBalance,
  unauthorized,
  rateLimit,
  timeout,
  network,
  invalidResponse,
  rejected,
  server,
  unknown,
}

class TonApiException implements Exception {
  const TonApiException({
    required this.kind,
    required this.message,
    this.statusCode,
    this.executionUncertain = false,
  });

  final TonApiErrorKind kind;
  final String message;
  final int? statusCode;
  final bool executionUncertain;

  @override
  String toString() =>
      'TonApiException(kind: ${kind.name}, status: $statusCode, '
      'uncertain: $executionUncertain, message: $message)';
}
