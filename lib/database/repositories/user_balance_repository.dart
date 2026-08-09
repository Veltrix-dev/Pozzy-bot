import 'package:pozzy_bot/database/database.dart';
import 'package:pozzy_bot/database/models/user_balance.dart';
import 'package:sqlite3/sqlite3.dart';


class UserBalanceRepository {
  Database get _db => AppDatabase.instance;

  UserBalance findOrEmpty(int telegramId) {
    final rows = _db.select(
      '''
      SELECT *
      FROM user_balances
      WHERE telegram_id = ?
      LIMIT 1;
      ''',
      [telegramId],
    );
    if (rows.isEmpty) return UserBalance.empty(telegramId);
    return UserBalance.fromMap(rows.first);
  }
  
  void credit({
    required int telegramId,
    required double amount,
    required String now,
  }) {
    if (amount <= 0) return;
    _db.execute(
      '''
      INSERT INTO user_balances (
        telegram_id,
        balance,
        updated_at
      ) VALUES (?, ?, ?)
      ON CONFLICT(telegram_id) DO UPDATE SET
        balance = balance + excluded.balance,
        updated_at = excluded.updated_at;
      ''',
      [telegramId, amount, now],
    );
  }
}
