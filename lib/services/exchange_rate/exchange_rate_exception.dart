enum ExchangeRateErrorKind {
  invalidAmount,
  configuration,
  network,
  timeout,
  httpClient,
  httpServer,
  apiRejected,
  malformedResponse,
  missingRubRate,
  staleRate,
  suspiciousRate,
  providerMismatch,
  storage,
  unexpected,
}

class ExchangeRateException implements Exception {
  const ExchangeRateException({
    required this.kind,
    required this.message,
    this.statusCode,
    this.apiErrorType,
  });

  final ExchangeRateErrorKind kind;
  final String message;
  final int? statusCode;
  final String? apiErrorType;

  @override
  String toString() {
    final status = statusCode == null ? '' : ' HTTP $statusCode';
    final apiError = apiErrorType == null ? '' : ' API $apiErrorType';
    return 'ExchangeRateException(${kind.name}$status$apiError): $message';
  }
}
