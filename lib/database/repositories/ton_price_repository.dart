import 'package:pozzy_bot/database/database.dart';
import 'package:pozzy_bot/database/models/usd_amount.dart';
import 'package:pozzy_bot/services/geckoterminal/ton_price_store.dart';
import 'package:sqlite3/sqlite3.dart';

class TonPriceRepository implements TonPriceStore {
  Database get _db => AppDatabase.instance;

  @override
  StoredTonPrice? findLast() {
    final rows = _db.select('''
      SELECT usd_per_ton_micros, fetched_at
      FROM ton_usd_price_cache
      WHERE id = 1
      LIMIT 1;
    ''');
    if (rows.isEmpty) return null;

    final micros = rows.first['usd_per_ton_micros'];
    final fetchedAtRaw = rows.first['fetched_at'];
    final fetchedAt = fetchedAtRaw is String
        ? DateTime.tryParse(fetchedAtRaw)
        : null;
    if (micros is! int || micros <= 0 || fetchedAt == null) {
      throw StateError('Stored TON/USD price is invalid');
    }
    return StoredTonPrice(
      usdPerTon: UsdAmount.fromMicros(micros),
      fetchedAt: fetchedAt.toUtc(),
    );
  }

  @override
  void save({required UsdAmount usdPerTon, required DateTime fetchedAt}) {
    if (usdPerTon.isZero) {
      throw ArgumentError.value(usdPerTon, 'usdPerTon');
    }
    _db.execute(
      '''
      INSERT INTO ton_usd_price_cache (id, usd_per_ton_micros, fetched_at)
      VALUES (1, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        usd_per_ton_micros = excluded.usd_per_ton_micros,
        fetched_at = excluded.fetched_at;
      ''',
      [usdPerTon.micros, fetchedAt.toUtc().toIso8601String()],
    );
  }
}
