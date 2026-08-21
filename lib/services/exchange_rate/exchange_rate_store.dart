enum ExchangeRateSource { twelveData, exchangeRateApi }

enum ExchangeRateObservationStatus { accepted, rejected }

class StoredExchangeRate {
  const StoredExchangeRate({
    required this.source,
    required this.rate,
    required this.sourceUpdatedAt,
    required this.fetchedAt,
  });

  final ExchangeRateSource source;
  final double rate;
  final DateTime sourceUpdatedAt;
  final DateTime fetchedAt;

  int get rateMicros => (rate * 1000000).round();
}

class ExchangeRateStoreException implements Exception {
  const ExchangeRateStoreException(this.message);

  final String message;

  @override
  String toString() => 'ExchangeRateStoreException: $message';
}

abstract interface class ExchangeRateStore {
  StoredExchangeRate? findUsdToRub(ExchangeRateSource source);

  void saveUsdToRub({
    required ExchangeRateSource source,
    required double rate,
    required DateTime sourceUpdatedAt,
    required DateTime fetchedAt,
  });

  void saveRejectedUsdToRub({
    required ExchangeRateSource source,
    required double rate,
    required DateTime sourceUpdatedAt,
    required DateTime fetchedAt,
    required String reason,
  });
}
