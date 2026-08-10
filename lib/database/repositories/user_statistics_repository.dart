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
    final purchases = _findPurchases(telegramId);
    final starsPurchases = purchases[UserPurchaseTypes.stars] ?? const [];
    final premiumPurchases = purchases[UserPurchaseTypes.premium] ?? const [];
    final tonPurchases = purchases[UserPurchaseTypes.ton] ?? const [];

    if (rows.isEmpty) {
      return UserStatistics(
        telegramId: telegramId,
        purchasesCount: 0,
        purchasesTotal: 0,
        referralCommissionTotal: 0,
        updatedAt: DateTime.now().toUtc(),
        starsPurchases: starsPurchases,
        premiumPurchases: premiumPurchases,
        tonPurchases: tonPurchases,
      );
    }
    return UserStatistics.fromMap(
      rows.first,
      starsPurchases: starsPurchases,
      premiumPurchases: premiumPurchases,
      tonPurchases: tonPurchases,
    );
  }

  void recordPurchase({
    required int telegramId,
    required double amount,
    String? purchaseId,
    String? purchaseType,
    double? quantity,
    DateTime? purchasedAt,
  }) {
    if (amount <= 0) return;
    final now = DateTime.now().toUtc().toIso8601String();
    final normalizedPurchaseId = purchaseId?.trim();
    final normalizedPurchaseType = purchaseType?.trim().toLowerCase();
    final hasPurchaseDetails =
        normalizedPurchaseId != null &&
        normalizedPurchaseId.isNotEmpty &&
        normalizedPurchaseType != null &&
        UserPurchaseTypes.values.contains(normalizedPurchaseType) &&
        quantity != null &&
        quantity > 0;

    _db.execute('BEGIN IMMEDIATE;');
    try {
      if (hasPurchaseDetails) {
        _db.execute(
          '''
          INSERT OR IGNORE INTO user_purchase_history (
            telegram_id,
            purchase_id,
            purchase_type,
            quantity,
            spent_usd,
            purchased_at
          ) VALUES (?, ?, ?, ?, ?, ?);
          ''',
          [
            telegramId,
            normalizedPurchaseId,
            normalizedPurchaseType,
            quantity,
            amount,
            (purchasedAt ?? DateTime.now()).toUtc().toIso8601String(),
          ],
        );
        if (_db.updatedRows == 0) {
          _db.execute('COMMIT;');
          return;
        }
      }

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
      _db.execute('COMMIT;');
    } catch (_) {
      _db.execute('ROLLBACK;');
      rethrow;
    }
  }

  Map<String, List<UserPurchaseEntry>> _findPurchases(int telegramId) {
    final rows = _db.select(
      '''
      SELECT purchase_type, quantity, spent_usd, purchased_at
      FROM user_purchase_history
      WHERE telegram_id = ?
      ORDER BY purchased_at DESC;
      ''',
      [telegramId],
    );
    final purchases = <String, List<UserPurchaseEntry>>{};
    for (final row in rows) {
      final type = row['purchase_type'] as String;
      purchases
          .putIfAbsent(type, () => [])
          .add(
            UserPurchaseEntry(
              purchasedAt: DateTime.parse(row['purchased_at'] as String),
              quantity: (row['quantity'] as num).toDouble(),
              spentUsd: (row['spent_usd'] as num).toDouble(),
            ),
          );
    }
    return purchases;
  }
}
