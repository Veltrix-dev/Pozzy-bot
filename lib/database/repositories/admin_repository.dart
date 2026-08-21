import 'package:pozzy_bot/database/database.dart';
import 'package:pozzy_bot/database/models/admin_statistics.dart';
import 'package:pozzy_bot/database/models/admin_user_snapshot.dart';
import 'package:pozzy_bot/database/models/gift_purchase_statuses.dart';
import 'package:pozzy_bot/database/models/user.dart';
import 'package:pozzy_bot/database/models/usd_amount.dart';
import 'package:pozzy_bot/database/repositories/user_repositories.dart';
import 'package:pozzy_bot/utils/telegram_username.dart';
import 'package:sqlite3/sqlite3.dart';

class AdminRepository {
  AdminRepository({UserRepositories? users})
    : _users = users ?? UserRepositories();

  final UserRepositories _users;

  Database get _db => AppDatabase.instance;

  AdminStatistics collectStatistics({DateTime? now}) {
    final generatedAt = (now ?? DateTime.now()).toUtc();
    final day = generatedAt.subtract(const Duration(days: 1)).toIso8601String();
    final week = generatedAt
        .subtract(const Duration(days: 7))
        .toIso8601String();
    final month = generatedAt
        .subtract(const Duration(days: 30))
        .toIso8601String();

    return AdminStatistics(
      generatedAt: generatedAt,
      users: _periodCounts('users', 'created_at', day, week, month),
      referrals: _periodCounts('referrals', 'created_at', day, week, month),
      stars: _fragmentPurchases('stars'),
      premium: _fragmentPurchases('premium'),
      ton: _fragmentPurchases('ton'),
      gifts: _giftPurchases(),
      failedOrders: _scalarInt(
        "SELECT COUNT(*) AS value FROM fragment_orders WHERE status = 'failed';",
      ),
      pendingOrders: _scalarInt(
        "SELECT COUNT(*) AS value FROM fragment_orders WHERE status IN ('created', 'processing');",
      ),
      totalBalanceMicros: _scalarInt(
        'SELECT COALESCE(SUM(balance_micros), 0) AS value FROM user_balances;',
      ),
    );
  }

  AdminUserSnapshot? findUserSnapshot(String rawQuery) {
    final query = rawQuery.trim();
    if (query.isEmpty) return null;
    final telegramId = int.tryParse(query);
    final username = TelegramUsername.normalize(query);
    final user = telegramId != null
        ? _users.findByTelegramId(telegramId)
        : username == null
        ? null
        : _users.findByUsername(username);
    if (user == null) return null;
    return _buildUserSnapshot(user);
  }

  AdminUserSnapshot? findUserSnapshotByTelegramId(int telegramId) {
    final user = _users.findByTelegramId(telegramId);
    return user == null ? null : _buildUserSnapshot(user);
  }

  List<int> listAllTelegramIds() => _users.listAllTelegramIds();

  AdminCreditResult creditBalance({
    required String requestId,
    required int adminTelegramId,
    required int targetTelegramId,
    required UsdAmount amount,
  }) {
    if (amount.isZero) {
      throw ArgumentError.value(amount, 'amount');
    }
    final now = DateTime.now().toUtc().toIso8601String();
    _db.execute('BEGIN IMMEDIATE;');
    try {
      if (_users.findByTelegramId(targetTelegramId) == null) {
        _db.execute('ROLLBACK;');
        return const AdminCreditResult(
          outcome: AdminCreditOutcome.targetMissing,
          balanceMicros: 0,
        );
      }

      _db.execute(
        '''
        INSERT OR IGNORE INTO admin_balance_adjustments (
          request_id,
          admin_telegram_id,
          target_telegram_id,
          amount_usd_micros,
          created_at
        ) VALUES (?, ?, ?, ?, ?);
        ''',
        [requestId, adminTelegramId, targetTelegramId, amount.micros, now],
      );
      if (_db.updatedRows == 0) {
        final balance = _balanceMicros(targetTelegramId);
        _db.execute('COMMIT;');
        return AdminCreditResult(
          outcome: AdminCreditOutcome.alreadyApplied,
          balanceMicros: balance,
        );
      }

      _db.execute(
        '''
        INSERT INTO user_balances (
          telegram_id,
          balance,
          balance_micros,
          updated_at
        ) VALUES (?, ?, ?, ?)
        ON CONFLICT(telegram_id) DO UPDATE SET
          balance = balance + excluded.balance,
          balance_micros = balance_micros + excluded.balance_micros,
          updated_at = excluded.updated_at;
        ''',
        [targetTelegramId, amount.toLegacyDouble(), amount.micros, now],
      );
      _insertAudit(
        adminTelegramId: adminTelegramId,
        action: 'balance_credit',
        targetTelegramId: targetTelegramId,
        details: 'request_id=$requestId amount_usd_micros=${amount.micros}',
        createdAt: now,
      );
      final balance = _balanceMicros(targetTelegramId);
      _db.execute('COMMIT;');
      return AdminCreditResult(
        outcome: AdminCreditOutcome.applied,
        balanceMicros: balance,
      );
    } catch (_) {
      _db.execute('ROLLBACK;');
      rethrow;
    }
  }

  void recordBroadcast({
    required int adminTelegramId,
    required int delivered,
    required int failed,
  }) {
    _insertAudit(
      adminTelegramId: adminTelegramId,
      action: 'broadcast',
      details: 'delivered=$delivered failed=$failed',
      createdAt: DateTime.now().toUtc().toIso8601String(),
    );
  }

  AdminPeriodCounts _periodCounts(
    String table,
    String dateColumn,
    String day,
    String week,
    String month,
  ) {
    final row = _db
        .select(
          '''
      SELECT
        COUNT(*) AS total,
        COALESCE(SUM(CASE WHEN $dateColumn >= ? THEN 1 ELSE 0 END), 0) AS day,
        COALESCE(SUM(CASE WHEN $dateColumn >= ? THEN 1 ELSE 0 END), 0) AS week,
        COALESCE(SUM(CASE WHEN $dateColumn >= ? THEN 1 ELSE 0 END), 0) AS month
      FROM $table;
      ''',
          [day, week, month],
        )
        .first;
    return AdminPeriodCounts(
      total: row['total'] as int? ?? 0,
      lastDay: row['day'] as int? ?? 0,
      lastWeek: row['week'] as int? ?? 0,
      lastMonth: row['month'] as int? ?? 0,
    );
  }

  AdminPurchaseStatistics _fragmentPurchases(String type) {
    final row = _db
        .select(
          '''
      SELECT
        COUNT(*) AS count,
        COALESCE(SUM(quantity_units), 0) AS quantity,
        COALESCE(SUM(price_usd_micros), 0) AS spent
      FROM fragment_orders
      WHERE purchase_type = ? AND status = 'completed';
      ''',
          [type],
        )
        .first;
    return AdminPurchaseStatistics(
      count: row['count'] as int? ?? 0,
      quantity: (row['quantity'] as num?)?.toDouble() ?? 0,
      spentUsdMicros: row['spent'] as int? ?? 0,
    );
  }

  AdminPurchaseStatistics _giftPurchases() {
    final row = _db
        .select(
          '''
      SELECT
        COUNT(*) AS count,
        COALESCE(SUM(price_usd), 0) AS spent
      FROM gift_purchases
      WHERE status = ?;
      ''',
          [GiftPurchaseStatuses.completed],
        )
        .first;
    return AdminPurchaseStatistics(
      count: row['count'] as int? ?? 0,
      quantity: (row['count'] as num?)?.toDouble() ?? 0,
      spentUsdMicros: (((row['spent'] as num?)?.toDouble() ?? 0) * 1000000)
          .round(),
    );
  }

  AdminUserSnapshot _buildUserSnapshot(User user) {
    final statistics = _db.select(
      '''
      SELECT purchases_count, purchases_total, purchases_total_micros
      FROM user_statistics
      WHERE telegram_id = ?;
      ''',
      [user.telegramId],
    );
    final invitedCount =
        _db.select(
              'SELECT COUNT(*) AS value FROM referrals WHERE referrer_telegram_id = ?;',
              [user.telegramId],
            ).first['value']
            as int? ??
        0;
    final purchasesTotalMicros = statistics.isEmpty
        ? 0
        : statistics.first['purchases_total_micros'] as int? ?? 0;
    final legacyPurchasesTotal = statistics.isEmpty
        ? 0.0
        : (statistics.first['purchases_total'] as num?)?.toDouble() ?? 0;
    return AdminUserSnapshot(
      user: user,
      balanceMicros: _balanceMicros(user.telegramId),
      purchasesCount: statistics.isEmpty
          ? 0
          : statistics.first['purchases_count'] as int? ?? 0,
      purchasesTotalMicros:
          purchasesTotalMicros == 0 && legacyPurchasesTotal != 0
          ? (legacyPurchasesTotal * 1000000).round()
          : purchasesTotalMicros,
      invitedCount: invitedCount,
    );
  }

  int _balanceMicros(int telegramId) {
    final rows = _db.select(
      'SELECT balance_micros FROM user_balances WHERE telegram_id = ?;',
      [telegramId],
    );
    return rows.isEmpty ? 0 : rows.first['balance_micros'] as int? ?? 0;
  }

  int _scalarInt(String sql) {
    final rows = _db.select(sql);
    return rows.isEmpty ? 0 : rows.first['value'] as int? ?? 0;
  }

  void _insertAudit({
    required int adminTelegramId,
    required String action,
    int? targetTelegramId,
    String? details,
    required String createdAt,
  }) {
    _db.execute(
      '''
      INSERT INTO admin_audit_log (
        admin_telegram_id,
        action,
        target_telegram_id,
        details,
        created_at
      ) VALUES (?, ?, ?, ?, ?);
      ''',
      [adminTelegramId, action, targetTelegramId, details, createdAt],
    );
  }
}
