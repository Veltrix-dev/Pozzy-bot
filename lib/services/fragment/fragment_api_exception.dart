enum FragmentApiErrorKind {
  configuration,
  network,
  timeout,
  httpClient,
  httpServer,
  rejected,
  malformedResponse,
}

class FragmentApiException implements Exception {
  const FragmentApiException({
    required this.kind,
    required this.message,
    this.statusCode,
    this.executionUncertain = false,
  });

  final FragmentApiErrorKind kind;
  final String message;
  final int? statusCode;
  final bool executionUncertain;

  @override
  String toString() {
    final status = statusCode == null ? '' : ' HTTP $statusCode';
    return 'FragmentApiException(${kind.name}$status): $message';
  }
}
