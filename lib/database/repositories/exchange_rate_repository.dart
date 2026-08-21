import 'package:pozzy_bot/database/database.dart';
import 'package:pozzy_bot/services/exchange_rate/exchange_rate_store.dart';
import 'package:sqlite3/sqlite3.dart';

class ExchangeRateRepository implements ExchangeRateStore {
  Database get _db => AppDatabase.instance;

  @override
  StoredExchangeRate? findUsdToRub(ExchangeRateSource source) {
    try {
      final table = _tableFor(source);
      final rows = _db.select('''
      SELECT rate_micros, source_updated_at, fetched_at
      FROM $table
      WHERE id = 1
      LIMIT 1;
    ''');
      if (rows.isEmpty) return null;

      final rateMicros = rows.first['rate_micros'];
      final sourceUpdatedRaw = rows.first['source_updated_at'];
      final fetchedRaw = rows.first['fetched_at'];
      final sourceUpdatedAt = sourceUpdatedRaw is String
          ? DateTime.tryParse(sourceUpdatedRaw)
          : null;
      final fetchedAt = fetchedRaw is String
          ? DateTime.tryParse(fetchedRaw)
          : null;
      if (rateMicros is! int ||
          rateMicros <= 0 ||
          sourceUpdatedAt == null ||
          fetchedAt == null) {
        throw const ExchangeRateStoreException(
          'Stored USD/RUB exchange rate is invalid',
        );
      }

      return StoredExchangeRate(
        source: source,
        rate: rateMicros / 1000000,
        sourceUpdatedAt: sourceUpdatedAt.toUtc(),
        fetchedAt: fetchedAt.toUtc(),
      );
    } on ExchangeRateStoreException {
      rethrow;
    } catch (_) {
      throw const ExchangeRateStoreException(
        'Failed to read stored USD/RUB exchange rate',
      );
    }
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
    try {
      final rateMicros = (rate * 1000000).round();
      final table = _tableFor(source);
      final fetchedAtUtc = fetchedAt.toUtc();
      _db.execute('BEGIN IMMEDIATE;');
      try {
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
            fetchedAtUtc.toIso8601String(),
          ],
        );
        _insertObservation(
          source: source,
          rateMicros: rateMicros,
          sourceUpdatedAt: sourceUpdatedAt,
          fetchedAt: fetchedAtUtc,
          status: ExchangeRateObservationStatus.accepted,
        );
        _db.execute('COMMIT;');
      } catch (_) {
        _db.execute('ROLLBACK;');
        rethrow;
      }
    } catch (_) {
      throw const ExchangeRateStoreException(
        'Failed to store USD/RUB exchange rate',
      );
    }
  }

  @override
  void saveRejectedUsdToRub({
    required ExchangeRateSource source,
    required double rate,
    required DateTime sourceUpdatedAt,
    required DateTime fetchedAt,
    required String reason,
  }) {
    if (!rate.isFinite || rate <= 0) return;
    try {
      _insertObservation(
        source: source,
        rateMicros: (rate * 1000000).round(),
        sourceUpdatedAt: sourceUpdatedAt,
        fetchedAt: fetchedAt,
        status: ExchangeRateObservationStatus.rejected,
        rejectionReason: reason,
      );
    } catch (_) {
      throw const ExchangeRateStoreException(
        'Failed to store rejected USD/RUB observation',
      );
    }
  }

  void _insertObservation({
    required ExchangeRateSource source,
    required int rateMicros,
    required DateTime sourceUpdatedAt,
    required DateTime fetchedAt,
    required ExchangeRateObservationStatus status,
    String? rejectionReason,
  }) {
    _db.execute(
      '''
      INSERT INTO exchange_rate_observations (
        source,
        rate_micros,
        source_updated_at,
        fetched_at,
        status,
        rejection_reason,
        created_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?);
      ''',
      [
        source.name,
        rateMicros,
        sourceUpdatedAt.toUtc().toIso8601String(),
        fetchedAt.toUtc().toIso8601String(),
        status.name,
        rejectionReason,
        DateTime.now().toUtc().toIso8601String(),
      ],
    );
  }

  String _tableFor(ExchangeRateSource source) => switch (source) {
    ExchangeRateSource.twelveData => 'usd_rub_exchange_rate',
    ExchangeRateSource.exchangeRateApi => 'usd_rub_fallback_exchange_rate',
  };
}
