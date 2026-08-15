import 'package:pozzy_bot/database/database.dart';
import 'package:pozzy_bot/database/models/usd_amount.dart';
import 'package:pozzy_bot/services/fragment_stars_api/fragment_star_price_store.dart';
import 'package:sqlite3/sqlite3.dart';

class FragmentStarPriceRepository implements FragmentStarPriceStore {
  Database get _db => AppDatabase.instance;

  @override
  StoredFragmentStarPrice? findLast() {
    final rows = _db.select('''
      SELECT usd_per_star_micros, fetched_at
      FROM fragment_star_price_cache
      WHERE id = 1
      LIMIT 1;
    ''');
    if (rows.isEmpty) return null;

    final micros = rows.first['usd_per_star_micros'] as int;
    final fetchedAt = DateTime.tryParse(rows.first['fetched_at'] as String);
    if (micros <= 0 || fetchedAt == null) {
      throw StateError('Stored Fragment Star price is invalid');
    }
    return StoredFragmentStarPrice(
      usdPerStar: UsdAmount.fromMicros(micros),
      fetchedAt: fetchedAt.toUtc(),
    );
  }

  @override
  void save({required UsdAmount usdPerStar, required DateTime fetchedAt}) {
    if (usdPerStar.isZero) {
      throw ArgumentError.value(usdPerStar, 'usdPerStar');
    }
    _db.execute(
      '''
      INSERT INTO fragment_star_price_cache (
        id, usd_per_star_micros, fetched_at
      ) VALUES (1, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        usd_per_star_micros = excluded.usd_per_star_micros,
        fetched_at = excluded.fetched_at;
      ''',
      [usdPerStar.micros, fetchedAt.toUtc().toIso8601String()],
    );
  }
}
