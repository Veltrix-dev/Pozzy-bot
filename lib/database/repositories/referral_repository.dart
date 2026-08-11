import 'package:pozzy_bot/config/config.dart';
import 'package:pozzy_bot/database/database.dart';
import 'package:pozzy_bot/database/models/referral_stats.dart';
import 'package:pozzy_bot/database/models/usd_amount.dart';
import 'package:pozzy_bot/database/repositories/user_balance_repository.dart';
import 'package:sqlite3/sqlite3.dart';

class ReferralRepository {
  ReferralRepository({UserBalanceRepository? balances})
    : _balances = balances ?? UserBalanceRepository();

  final UserBalanceRepository _balances;

  Database get _db => AppDatabase.instance;

  ReferralRegisterResult tryRegisterReferral({
    required int referralTelegramId,
    required String referralCode,
  }) {
    final normalizedCode = referralCode.trim().toUpperCase();
    if (normalizedCode.isEmpty) {
      return ReferralRegisterResult(
        outcome: ReferralRegisterOutcome.referrerNotFound,
      );
    }

    _db.execute('BEGIN IMMEDIATE;');
    try {
      final referrerRows = _db.select(
        '''
        SELECT telegram_id FROM users
        WHERE referral_code = ? COLLATE NOCASE
        LIMIT 1;
        ''',
        [normalizedCode],
      );
      if (referrerRows.isEmpty) {
        _db.execute('ROLLBACK;');
        return ReferralRegisterResult(
          outcome: ReferralRegisterOutcome.referrerNotFound,
        );
      }

      final referrerTelegramId = referrerRows.first['telegram_id'] as int;
      if (referrerTelegramId == referralTelegramId) {
        _db.execute('ROLLBACK;');
        return ReferralRegisterResult(
          outcome: ReferralRegisterOutcome.selfReferral,
        );
      }

      if (_hasExistingReferralLink(referralTelegramId)) {
        _db.execute('ROLLBACK;');
        return ReferralRegisterResult(
          outcome: ReferralRegisterOutcome.alreadyReferred,
        );
      }

      final now = DateTime.now().toUtc().toIso8601String();
      _db.execute(
        '''
        INSERT INTO referrals (
          referrer_telegram_id,
          referral_telegram_id,
          created_at
        ) VALUES (?, ?, ?);
        ''',
        [referrerTelegramId, referralTelegramId, now],
      );

      _db.execute(
        '''
        UPDATE users
        SET referred_by_telegram_id = ?, updated_at = ?
        WHERE telegram_id = ? AND referred_by_telegram_id IS NULL;
        ''',
        [referrerTelegramId, now, referralTelegramId],
      );

      if (_db.updatedRows == 0) {
        _db.execute('ROLLBACK;');
        return ReferralRegisterResult(
          outcome: ReferralRegisterOutcome.alreadyReferred,
        );
      }

      _db.execute('COMMIT;');
      return ReferralRegisterResult(
        outcome: ReferralRegisterOutcome.success,
        referrerTelegramId: referrerTelegramId,
      );
    } catch (_) {
      _db.execute('ROLLBACK;');
      rethrow;
    }
  }

  ReferralPurchaseCommissionResult? tryCreditPurchaseCommission({
    required int referralTelegramId,
    required String purchaseId,
    required double purchaseAmount,
  }) {
    if (purchaseAmount <= 0) return null;
    return tryCreditPurchaseCommissionExact(
      referralTelegramId: referralTelegramId,
      purchaseId: purchaseId,
      purchaseAmount: UsdAmount.fromLegacyDouble(purchaseAmount),
    );
  }

  ReferralPurchaseCommissionResult? tryCreditPurchaseCommissionExact({
    required int referralTelegramId,
    required String purchaseId,
    required UsdAmount purchaseAmount,
  }) {
    if (purchaseAmount.isZero || purchaseId.trim().isEmpty) return null;

    _db.execute('BEGIN IMMEDIATE;');
    try {
      final existing = _db.select(
        '''
        SELECT referrer_telegram_id, referral_telegram_id,
               purchase_amount_micros, commission_amount_micros
        FROM referral_purchase_commissions
        WHERE purchase_id = ?
        LIMIT 1;
        ''',
        [purchaseId],
      );
      if (existing.isNotEmpty) {
        _db.execute('COMMIT;');
        final row = existing.first;
        return ReferralPurchaseCommissionResult(
          referrerTelegramId: row['referrer_telegram_id'] as int,
          referralTelegramId: row['referral_telegram_id'] as int,
          purchaseAmount: UsdAmount.fromMicros(
            row['purchase_amount_micros'] as int,
          ).toLegacyDouble(),
          commissionAmount: UsdAmount.fromMicros(
            row['commission_amount_micros'] as int,
          ).toLegacyDouble(),
          wasCredited: false,
        );
      }

      final referrerTelegramId = _resolveReferrerTelegramId(referralTelegramId);
      if (referrerTelegramId == null) {
        _db.execute('COMMIT;');
        return null;
      }

      final now = DateTime.now().toUtc().toIso8601String();
      final commission = purchaseAmount.multiplyFraction(
        Config.referralPurchaseFractionRaw,
        roundToCents: true,
      );
      if (commission.isZero) {
        _db.execute('COMMIT;');
        return null;
      }

      _db.execute(
        '''
        INSERT INTO referral_purchase_commissions (
          referrer_telegram_id,
          referral_telegram_id,
          purchase_id,
          purchase_amount,
          commission_amount,
          purchase_amount_micros,
          commission_amount_micros,
          created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?);
        ''',
        [
          referrerTelegramId,
          referralTelegramId,
          purchaseId,
          purchaseAmount.toLegacyDouble(),
          commission.toLegacyDouble(),
          purchaseAmount.micros,
          commission.micros,
          now,
        ],
      );

      _upsertStatistic(
        telegramId: referrerTelegramId,
        referralCommissionDelta: commission,
        now: now,
      );

      // Атомарно начисляем баланс реферера в той же транзакции.
      _balances.creditExact(
        telegramId: referrerTelegramId,
        amount: commission,
        now: now,
      );

      _db.execute('COMMIT;');
      return ReferralPurchaseCommissionResult(
        referrerTelegramId: referrerTelegramId,
        referralTelegramId: referralTelegramId,
        purchaseAmount: purchaseAmount.toLegacyDouble(),
        commissionAmount: commission.toLegacyDouble(),
        wasCredited: true,
      );
    } catch (_) {
      _db.execute('ROLLBACK;');
      rethrow;
    }
  }

  ReferralStats statsForReferrer(int referrerTelegramId) {
    final countRows = _db.select(
      '''
      SELECT COUNT(*) AS count
      FROM referrals
      WHERE referrer_telegram_id = ?;
      ''',
      [referrerTelegramId],
    );
    final invitedCount = (countRows.first['count'] as int?) ?? 0;

    final commissionRows = _db.select(
      '''
      SELECT COALESCE(SUM(commission_amount), 0) AS total
      FROM referral_purchase_commissions
      WHERE referrer_telegram_id = ?;
      ''',
      [referrerTelegramId],
    );
    final commissionTotal =
        (commissionRows.first['total'] as num?)?.toDouble() ?? 0;

    final referralRows = _db.select(
      '''
      SELECT
        r.referral_telegram_id,
        u.username,
        r.created_at,
        COALESCE(SUM(c.commission_amount), 0) AS commission_amount
      FROM referrals r
      LEFT JOIN users u ON u.telegram_id = r.referral_telegram_id
      LEFT JOIN referral_purchase_commissions c
        ON c.referrer_telegram_id = r.referrer_telegram_id
        AND c.referral_telegram_id = r.referral_telegram_id
      WHERE r.referrer_telegram_id = ?
      GROUP BY r.referral_telegram_id
      ORDER BY r.created_at DESC;
      ''',
      [referrerTelegramId],
    );

    final referrals = referralRows
        .map(
          (row) => ReferralEntry(
            telegramId: row['referral_telegram_id'] as int,
            username: row['username'] as String?,
            joinedAt: DateTime.parse(row['created_at'] as String),
            commissionAmount:
                (row['commission_amount'] as num?)?.toDouble() ?? 0,
          ),
        )
        .toList();

    return ReferralStats(
      invitedCount: invitedCount,
      commissionTotal: commissionTotal,
      referrals: referrals,
    );
  }

  bool _hasExistingReferralLink(int referralTelegramId) {
    final referralRows = _db.select(
      '''
      SELECT 1 FROM referrals
      WHERE referral_telegram_id = ?
      LIMIT 1;
      ''',
      [referralTelegramId],
    );
    if (referralRows.isNotEmpty) return true;

    final userRows = _db.select(
      '''
      SELECT referred_by_telegram_id
      FROM users
      WHERE telegram_id = ?
      LIMIT 1;
      ''',
      [referralTelegramId],
    );
    if (userRows.isEmpty) return false;
    return userRows.first['referred_by_telegram_id'] != null;
  }

  int? _resolveReferrerTelegramId(int referralTelegramId) {
    final userRows = _db.select(
      '''
      SELECT referred_by_telegram_id
      FROM users
      WHERE telegram_id = ?
      LIMIT 1;
      ''',
      [referralTelegramId],
    );
    if (userRows.isNotEmpty) {
      final referredBy = userRows.first['referred_by_telegram_id'] as int?;
      if (referredBy != null) return referredBy;
    }

    final referralRows = _db.select(
      '''
      SELECT referrer_telegram_id
      FROM referrals
      WHERE referral_telegram_id = ?
      LIMIT 1;
      ''',
      [referralTelegramId],
    );
    if (referralRows.isEmpty) return null;
    return referralRows.first['referrer_telegram_id'] as int;
  }

  void _upsertStatistic({
    required int telegramId,
    required UsdAmount referralCommissionDelta,
    required String now,
  }) {
    _db.execute(
      '''
      INSERT INTO user_statistics (
        telegram_id,
        referral_commission_total,
        referral_commission_total_micros,
        updated_at
      ) VALUES (?, ?, ?, ?)
      ON CONFLICT(telegram_id) DO UPDATE SET
        referral_commission_total = referral_commission_total + excluded.referral_commission_total,
        referral_commission_total_micros =
          referral_commission_total_micros + excluded.referral_commission_total_micros,
        updated_at = excluded.updated_at;
      ''',
      [
        telegramId,
        referralCommissionDelta.toLegacyDouble(),
        referralCommissionDelta.micros,
        now,
      ],
    );
  }
}
