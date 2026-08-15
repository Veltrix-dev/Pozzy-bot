import 'package:pozzy_bot/database/database.dart';
import 'package:pozzy_bot/database/models/fragment_order.dart';
import 'package:pozzy_bot/database/models/fragment_order_status.dart';
import 'package:pozzy_bot/database/models/fragment_purchase_type.dart';
import 'package:pozzy_bot/database/models/usd_amount.dart';
import 'package:sqlite3/sqlite3.dart';

enum FragmentOrderCreateOutcome { created, existing, idempotencyConflict }

class FragmentOrderCreateResult {
  const FragmentOrderCreateResult(this.outcome, {this.order});

  final FragmentOrderCreateOutcome outcome;
  final FragmentOrder? order;
}

enum FragmentOrderBeginOutcome {
  started,
  alreadyProcessing,
  alreadyCompleted,
  invalidStatus,
  notFound,
}

class FragmentOrderRepository {
  Database get _db => AppDatabase.instance;

  FragmentOrderCreateResult create({
    required String orderId,
    required String idempotencyKey,
    required int buyerTelegramId,
    required FragmentPurchaseType purchaseType,
    required int quantityUnits,
    required UsdAmount price,
    required String recipientUsername,
  }) {
    _db.execute('BEGIN IMMEDIATE;');
    try {
      final existing = _findByIdempotencyKey(idempotencyKey);
      if (existing != null) {
        _db.execute('COMMIT;');
        final matches =
            existing.buyerTelegramId == buyerTelegramId &&
            existing.purchaseType == purchaseType &&
            existing.quantityUnits == quantityUnits &&
            existing.recipientUsername.toLowerCase() ==
                recipientUsername.toLowerCase();
        return FragmentOrderCreateResult(
          matches
              ? FragmentOrderCreateOutcome.existing
              : FragmentOrderCreateOutcome.idempotencyConflict,
          order: existing,
        );
      }

      final now = DateTime.now().toUtc().toIso8601String();
      _db.execute(
        '''
        INSERT INTO fragment_orders (
          order_id, idempotency_key, buyer_telegram_id, purchase_type,
          quantity_units, price_usd_micros, recipient_username, status,
          created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        ''',
        [
          orderId,
          idempotencyKey,
          buyerTelegramId,
          purchaseType.databaseValue,
          quantityUnits,
          price.micros,
          recipientUsername,
          FragmentOrderStatus.created.databaseValue,
          now,
          now,
        ],
      );
      _db.execute('COMMIT;');
      return FragmentOrderCreateResult(
        FragmentOrderCreateOutcome.created,
        order: findByOrderId(orderId),
      );
    } catch (_) {
      _db.execute('ROLLBACK;');
      rethrow;
    }
  }

  FragmentOrderBeginOutcome tryBeginProcessing(String orderId) {
    _db.execute('BEGIN IMMEDIATE;');
    try {
      final order = _findByOrderId(orderId);
      if (order == null) {
        _db.execute('ROLLBACK;');
        return FragmentOrderBeginOutcome.notFound;
      }
      if (order.status == FragmentOrderStatus.processing) {
        _db.execute('COMMIT;');
        return FragmentOrderBeginOutcome.alreadyProcessing;
      }
      if (order.status == FragmentOrderStatus.completed) {
        _db.execute('COMMIT;');
        return FragmentOrderBeginOutcome.alreadyCompleted;
      }
      if (order.status != FragmentOrderStatus.created) {
        _db.execute('ROLLBACK;');
        return FragmentOrderBeginOutcome.invalidStatus;
      }

      final now = DateTime.now().toUtc().toIso8601String();
      _db.execute(
        '''
        UPDATE fragment_orders
        SET status = ?, attempt_count = attempt_count + 1,
            balance_reserved_at = NULL, error_code = NULL, error_detail = NULL,
            updated_at = ?
        WHERE order_id = ? AND status = ?;
        ''',
        [
          FragmentOrderStatus.processing.databaseValue,
          now,
          orderId,
          FragmentOrderStatus.created.databaseValue,
        ],
      );
      if (_db.updatedRows == 0) {
        _db.execute('ROLLBACK;');
        return FragmentOrderBeginOutcome.invalidStatus;
      }

      _db.execute('COMMIT;');
      return FragmentOrderBeginOutcome.started;
    } catch (_) {
      _db.execute('ROLLBACK;');
      rethrow;
    }
  }

  FragmentOrder? markCompleted({
    required String orderId,
    required String apiResponseJson,
    String? externalReference,
  }) {
    _db.execute('BEGIN IMMEDIATE;');
    try {
      final order = _findByOrderId(orderId);
      if (order == null || order.status != FragmentOrderStatus.processing) {
        _db.execute('ROLLBACK;');
        return null;
      }

      final now = DateTime.now().toUtc().toIso8601String();
      _db.execute(
        '''
        UPDATE fragment_orders
        SET status = ?, external_reference = ?, api_response_json = ?,
            error_code = NULL, error_detail = NULL, completed_at = ?,
            updated_at = ?
        WHERE order_id = ? AND status = ?;
        ''',
        [
          FragmentOrderStatus.completed.databaseValue,
          externalReference,
          apiResponseJson,
          now,
          now,
          orderId,
          FragmentOrderStatus.processing.databaseValue,
        ],
      );
      if (_db.updatedRows == 0) {
        _db.execute('ROLLBACK;');
        return null;
      }

      _db.execute(
        '''
        INSERT OR IGNORE INTO user_purchase_history (
          telegram_id, purchase_id, purchase_type, quantity, spent_usd,
          spent_usd_micros, purchased_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?);
        ''',
        [
          order.buyerTelegramId,
          order.orderId,
          order.purchaseType.databaseValue,
          _legacyQuantity(order),
          order.price.toLegacyDouble(),
          order.price.micros,
          now,
        ],
      );

      _db.execute(
        '''
        INSERT INTO user_statistics (
          telegram_id, purchases_count, purchases_total,
          purchases_total_micros, updated_at
        ) VALUES (?, 1, ?, ?, ?)
        ON CONFLICT(telegram_id) DO UPDATE SET
          purchases_count = purchases_count + 1,
          purchases_total = purchases_total + excluded.purchases_total,
          purchases_total_micros =
            purchases_total_micros + excluded.purchases_total_micros,
          updated_at = excluded.updated_at;
        ''',
        [
          order.buyerTelegramId,
          order.price.toLegacyDouble(),
          order.price.micros,
          now,
        ],
      );

      _db.execute('COMMIT;');
      return findByOrderId(orderId);
    } catch (_) {
      _db.execute('ROLLBACK;');
      rethrow;
    }
  }

  bool markFailedAndRefund({
    required String orderId,
    required String errorCode,
    required String errorDetail,
  }) {
    _db.execute('BEGIN IMMEDIATE;');
    try {
      final order = _findByOrderId(orderId);
      if (order == null || order.status.isFinal) {
        _db.execute('ROLLBACK;');
        return false;
      }

      final now = DateTime.now().toUtc().toIso8601String();
      if (order.status == FragmentOrderStatus.processing &&
          order.balanceReservedAt != null) {
        _db.execute(
          '''
          UPDATE user_balances
          SET balance = (balance_micros + ?) / 1000000.0,
              balance_micros = balance_micros + ?,
              updated_at = ?
          WHERE telegram_id = ?;
          ''',
          [order.price.micros, order.price.micros, now, order.buyerTelegramId],
        );
        if (_db.updatedRows == 0) {
          _db.execute('ROLLBACK;');
          return false;
        }
      }

      _db.execute(
        '''
        UPDATE fragment_orders
        SET status = ?, error_code = ?, error_detail = ?, updated_at = ?
        WHERE order_id = ? AND status IN (?, ?);
        ''',
        [
          FragmentOrderStatus.failed.databaseValue,
          errorCode,
          _safeDetail(errorDetail),
          now,
          orderId,
          FragmentOrderStatus.created.databaseValue,
          FragmentOrderStatus.processing.databaseValue,
        ],
      );
      if (_db.updatedRows == 0) {
        _db.execute('ROLLBACK;');
        return false;
      }
      _db.execute('COMMIT;');
      return true;
    } catch (_) {
      _db.execute('ROLLBACK;');
      rethrow;
    }
  }

  bool markProcessingUncertain({
    required String orderId,
    required String errorCode,
    required String errorDetail,
  }) {
    final now = DateTime.now().toUtc().toIso8601String();
    _db.execute(
      '''
      UPDATE fragment_orders
      SET error_code = ?, error_detail = ?, updated_at = ?
      WHERE order_id = ? AND status = ?;
      ''',
      [
        errorCode,
        _safeDetail(errorDetail),
        now,
        orderId,
        FragmentOrderStatus.processing.databaseValue,
      ],
    );
    return _db.updatedRows > 0;
  }

  bool recordCreatedError({
    required String orderId,
    required String errorCode,
    required String errorDetail,
  }) {
    final now = DateTime.now().toUtc().toIso8601String();
    _db.execute(
      '''
      UPDATE fragment_orders
      SET error_code = ?, error_detail = ?, updated_at = ?
      WHERE order_id = ? AND status = ?;
      ''',
      [
        errorCode,
        _safeDetail(errorDetail),
        now,
        orderId,
        FragmentOrderStatus.created.databaseValue,
      ],
    );
    return _db.updatedRows > 0;
  }

  bool cancelCreated(String orderId) {
    final now = DateTime.now().toUtc().toIso8601String();
    _db.execute(
      '''
      UPDATE fragment_orders
      SET status = ?, error_code = NULL, error_detail = NULL, updated_at = ?
      WHERE order_id = ? AND status = ?;
      ''',
      [
        FragmentOrderStatus.cancelled.databaseValue,
        now,
        orderId,
        FragmentOrderStatus.created.databaseValue,
      ],
    );
    return _db.updatedRows > 0;
  }

  FragmentOrder? findByOrderId(String orderId) => _findByOrderId(orderId);

  FragmentOrder? findByIdempotencyKey(String idempotencyKey) =>
      _findByIdempotencyKey(idempotencyKey);

  List<FragmentOrder> findProcessingOlderThan(Duration age, {int limit = 100}) {
    final cutoff = DateTime.now().toUtc().subtract(age).toIso8601String();
    final rows = _db.select(
      '''
      SELECT * FROM fragment_orders
      WHERE status = ? AND updated_at <= ?
      ORDER BY updated_at ASC
      LIMIT ?;
      ''',
      [FragmentOrderStatus.processing.databaseValue, cutoff, limit],
    );
    return rows.map(FragmentOrder.fromMap).toList(growable: false);
  }

  FragmentOrder? _findByOrderId(String orderId) {
    final rows = _db.select(
      'SELECT * FROM fragment_orders WHERE order_id = ? LIMIT 1;',
      [orderId],
    );
    return rows.isEmpty ? null : FragmentOrder.fromMap(rows.first);
  }

  FragmentOrder? _findByIdempotencyKey(String idempotencyKey) {
    final rows = _db.select(
      'SELECT * FROM fragment_orders WHERE idempotency_key = ? LIMIT 1;',
      [idempotencyKey],
    );
    return rows.isEmpty ? null : FragmentOrder.fromMap(rows.first);
  }

  double _legacyQuantity(FragmentOrder order) {
    return switch (order.purchaseType) {
      FragmentPurchaseType.stars ||
      FragmentPurchaseType.premium => order.quantityUnits.toDouble(),
      FragmentPurchaseType.ton => order.quantityUnits / 1000000000,
    };
  }
}

String _safeDetail(String value) {
  final normalized = value.replaceAll(RegExp(r'[\r\n]+'), ' ').trim();
  return normalized.length <= 500 ? normalized : normalized.substring(0, 500);
}
