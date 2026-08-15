enum ExchangeRateSource { twelveData, exchangeRateApi }

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
}

abstract interface class ExchangeRateStore {
  StoredExchangeRate? findUsdToRub(ExchangeRateSource source);

  void saveUsdToRub({
    required ExchangeRateSource source,
    required double rate,
    required DateTime sourceUpdatedAt,
    required DateTime fetchedAt,
  });
}
