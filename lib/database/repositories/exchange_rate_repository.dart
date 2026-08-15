import 'package:pozzy_bot/database/database.dart';
import 'package:pozzy_bot/services/exchange_rate/exchange_rate_store.dart';
import 'package:sqlite3/sqlite3.dart';

class ExchangeRateRepository implements ExchangeRateStore {
  Database get _db => AppDatabase.instance;

  @override
  StoredExchangeRate? findUsdToRub(ExchangeRateSource source) {
    final table = _tableFor(source);
    final rows = _db.select('''
      SELECT rate_micros, source_updated_at, fetched_at
      FROM $table
      WHERE id = 1
      LIMIT 1;
    ''');
    if (rows.isEmpty) return null;

    final rateMicros = rows.first['rate_micros'] as int;
    final sourceUpdatedAt = DateTime.tryParse(
      rows.first['source_updated_at'] as String,
    );
    final fetchedAt = DateTime.tryParse(rows.first['fetched_at'] as String);
    if (rateMicros <= 0 || sourceUpdatedAt == null || fetchedAt == null) {
      throw StateError('Stored USD/RUB exchange rate is invalid');
    }

    return StoredExchangeRate(
      source: source,
      rate: rateMicros / 1000000,
      sourceUpdatedAt: sourceUpdatedAt.toUtc(),
      fetchedAt: fetchedAt.toUtc(),
    );
  }

  @override
  void saveUsdToRub({
    required ExchangeRateSource source,
    required double rate,
    required DateTime sourceUpdatedAt,
    required DateTime fetchedAt,
  }) {
    if (!rate.isFinite || rate <= 0) {
      throw ArgumentError.value(rate, 'rate');
    }
    final rateMicros = (rate * 1000000).round();
    final table = _tableFor(source);
    _db.execute(
      '''
      INSERT INTO $table (
        id, rate_micros, source_updated_at, fetched_at
      ) VALUES (1, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        rate_micros = excluded.rate_micros,
        source_updated_at = excluded.source_updated_at,
        fetched_at = excluded.fetched_at;
      ''',
      [
        rateMicros,
        sourceUpdatedAt.toUtc().toIso8601String(),
        fetchedAt.toUtc().toIso8601String(),
      ],
    );
  }

  String _tableFor(ExchangeRateSource source) => switch (source) {
    ExchangeRateSource.twelveData => 'usd_rub_exchange_rate',
    ExchangeRateSource.exchangeRateApi => 'usd_rub_fallback_exchange_rate',
  };
}
