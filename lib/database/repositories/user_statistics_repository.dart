import 'package:pozzy_bot/database/database.dart';
import 'package:pozzy_bot/database/models/user_statistics.dart';
import 'package:sqlite3/sqlite3.dart';

class UserStatisticsRepository {
  Database get _db => AppDatabase.instance;

  UserStatistics findOrEmpty(int telegramId) {
    final rows = _db.select(
      '''
      SELECT *
      FROM user_statistics
      WHERE telegram_id = ?
      LIMIT 1;
      ''',
      [telegramId],
    );
    if (rows.isEmpty) return UserStatistics.empty(telegramId);
    return UserStatistics.fromMap(rows.first);
  }

  void recordPurchase({
    required int telegramId,
    required double amount,
  }) {
    if (amount <= 0) return;
    final now = DateTime.now().toUtc().toIso8601String();
    _db.execute(
      '''
      INSERT INTO user_statistics (
        telegram_id,
        purchases_count,
        purchases_total,
        updated_at
      ) VALUES (?, 1, ?, ?)
      ON CONFLICT(telegram_id) DO UPDATE SET
        purchases_count = purchases_count + 1,
        purchases_total = purchases_total + excluded.purchases_total,
        updated_at = excluded.updated_at;
      ''',
      [telegramId, amount, now],
    );
  }
}
