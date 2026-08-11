import 'package:pozzy_bot/database/database.dart';
import 'package:pozzy_bot/database/models/gift_purchase.dart';
import 'package:pozzy_bot/database/models/gift_purchase_statuses.dart';
import 'package:sqlite3/sqlite3.dart';

enum GiftBeginDeliveryResult {
  started,
  alreadyProcessing,
  alreadyCompleted,
  paymentConflict,
}

class GiftPurchaseRepository {
  Database get _db => AppDatabase.instance;

  GiftBeginDeliveryResult tryBeginPaidDelivery({
    required String paymentId,
    required int buyerTelegramId,
    required String giftKind,
    required String giftId,
    required double priceUsd,
    required String recipient,
    int? recipientTelegramId,
  }) {
    _db.execute('BEGIN IMMEDIATE;');
    try {
      final existing = _findByPaymentId(paymentId);
      if (existing != null) {
        if (!_matchesPaidProduct(
          existing,
          buyerTelegramId: buyerTelegramId,
          giftKind: giftKind,
          giftId: giftId,
          priceUsd: priceUsd,
        )) {
          _db.execute('ROLLBACK;');
          return GiftBeginDeliveryResult.paymentConflict;
        }
        if (existing.status == GiftPurchaseStatuses.completed) {
          _db.execute('COMMIT;');
          return GiftBeginDeliveryResult.alreadyCompleted;
        }
        if (existing.status == GiftPurchaseStatuses.processing) {
          _db.execute('COMMIT;');
          return GiftBeginDeliveryResult.alreadyProcessing;
        }

        final now = DateTime.now().toUtc().toIso8601String();
        _db.execute(
          '''
          UPDATE gift_purchases
          SET recipient = ?, recipient_telegram_id = ?, status = ?,
              error_code = NULL, error_detail = NULL, updated_at = ?
          WHERE payment_id = ? AND status = ?;
          ''',
          [
            recipient,
            recipientTelegramId,
            GiftPurchaseStatuses.processing,
            now,
            paymentId,
            GiftPurchaseStatuses.failed,
          ],
        );
        if (_db.updatedRows == 0) {
          _db.execute('ROLLBACK;');
          return GiftBeginDeliveryResult.alreadyProcessing;
        }
        _db.execute('COMMIT;');
        return GiftBeginDeliveryResult.started;
      }

      final now = DateTime.now().toUtc().toIso8601String();
      _db.execute(
        '''
        INSERT INTO gift_purchases (
          payment_id,
          buyer_telegram_id,
          gift_kind,
          gift_id,
          price_usd,
          recipient,
          recipient_telegram_id,
          status,
          created_at,
          updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        ''',
        [
          paymentId,
          buyerTelegramId,
          giftKind,
          giftId,
          priceUsd,
          recipient,
          recipientTelegramId,
          GiftPurchaseStatuses.processing,
          now,
          now,
        ],
      );
      _db.execute('COMMIT;');
      return GiftBeginDeliveryResult.started;
    } catch (_) {
      _db.execute('ROLLBACK;');
      rethrow;
    }
  }

  GiftPurchase? markCompletedAndRecordStatistics(String paymentId) {
    _db.execute('BEGIN IMMEDIATE;');
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      _db.execute(
        '''
        UPDATE gift_purchases
        SET status = ?, error_code = NULL, error_detail = NULL, updated_at = ?
        WHERE payment_id = ? AND status = ?;
        ''',
        [
          GiftPurchaseStatuses.completed,
          now,
          paymentId,
          GiftPurchaseStatuses.processing,
        ],
      );
      if (_db.updatedRows == 0) {
        _db.execute('ROLLBACK;');
        return null;
      }

      final completed = _findByPaymentId(paymentId)!;
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
        [completed.buyerTelegramId, completed.priceUsd, now],
      );

      _db.execute('COMMIT;');
      return completed;
    } catch (_) {
      _db.execute('ROLLBACK;');
      rethrow;
    }
  }

  bool markFailed(String paymentId, {String? errorCode, String? errorDetail}) {
    final now = DateTime.now().toUtc().toIso8601String();
    _db.execute(
      '''
      UPDATE gift_purchases
      SET status = ?, error_code = ?, error_detail = ?, updated_at = ?
      WHERE payment_id = ? AND status = ?;
      ''',
      [
        GiftPurchaseStatuses.failed,
        errorCode,
        errorDetail,
        now,
        paymentId,
        GiftPurchaseStatuses.processing,
      ],
    );
    return _db.updatedRows > 0;
  }

  GiftPurchase? findByPaymentId(String paymentId) {
    return _findByPaymentId(paymentId);
  }

  List<GiftPurchase> findCompletedForBuyer(int buyerTelegramId) {
    final rows = _db.select(
      '''
      SELECT * FROM gift_purchases
      WHERE buyer_telegram_id = ? AND status = ?
      ORDER BY updated_at DESC;
      ''',
      [buyerTelegramId, GiftPurchaseStatuses.completed],
    );
    return rows.map(GiftPurchase.fromMap).toList();
  }

  GiftPurchase? _findByPaymentId(String paymentId) {
    final rows = _db.select(
      'SELECT * FROM gift_purchases WHERE payment_id = ? LIMIT 1;',
      [paymentId],
    );
    if (rows.isEmpty) return null;
    return GiftPurchase.fromMap(rows.first);
  }

  bool _matchesPaidProduct(
    GiftPurchase purchase, {
    required int buyerTelegramId,
    required String giftKind,
    required String giftId,
    required double priceUsd,
  }) {
    return purchase.buyerTelegramId == buyerTelegramId &&
        purchase.giftKind == giftKind &&
        purchase.giftId == giftId &&
        (purchase.priceUsd - priceUsd).abs() < 0.000001;
  }
}
