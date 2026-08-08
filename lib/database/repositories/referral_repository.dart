import 'package:pozzy_bot/database/database.dart';
import 'package:pozzy_bot/database/models/referral_stats.dart';
import 'package:sqlite3/sqlite3.dart';

class ReferralRepository {
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

    _db.execute('BEGIN IMMEDIATE');
    try {
      final referrerRows = _db.select(
        '''
        SELECT telegram_id FROM users
        WHERE referral_code = ? COLLATE NOCASE
        LIMIT 1;
        ''', 
      [normalizedCode],
      );
      if(referrerRows.isEmpty) {
        _db.execute('ROLLBACK;');
        return ReferralRegisterResult(
          outcome: ReferralRegisterOutcome.referrerNotFound,
          );
      }

      final referrerTelegramId = referrerRows.first['telegram_id'] as int;
      if(referrerTelegramId == referralTelegramId) {
        _db.execute('ROLLBACK;');
        return ReferralRegisterResult(
          outcome: ReferralRegisterOutcome.selfReferral,
        );
      }

      if(_hasExistingReferralLink(referrerTelegramId)) {
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

      if(_db.updatedRows == 0) {
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
    }catch (_) {
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
  
  final referralRows = _db.select(
      '''
      SELECT
        r.referral_telegram_id,
        u.username,
        r.created_at,
        COALESCE(SUM(c.commission_usd), 0) AS top_up_income_usd
      FROM referrals r
      LEFT JOIN users u ON u.telegram_id = r.referral_telegram_id
      LEFT JOIN referral_topup_commissions c
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
    ), 
  ).toList();

  return ReferralStats(
    invitedCount: invitedCount,
    referrals: referrals
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
  if(referralRows.isNotEmpty) return true;

  final userRows = _db.select(
      '''
      SELECT referred_by_telegram_id
      FROM users
      WHERE telegram_id = ?
      LIMIT 1;
      ''', 
  );
  if(userRows.isEmpty) return false;
  return userRows.first['referred_by_telegram_id'] != null;
}
}