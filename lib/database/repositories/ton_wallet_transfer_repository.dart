import 'package:pozzy_bot/database/database.dart';
import 'package:pozzy_bot/database/models/ton_amount.dart';
import 'package:pozzy_bot/database/models/ton_wallet_transfer.dart';
import 'package:pozzy_bot/database/models/usd_amount.dart';
import 'package:sqlite3/sqlite3.dart';

enum TonTransferCreateOutcome { created, existing, idempotencyConflict }

class TonTransferCreateResult {
  const TonTransferCreateResult(this.outcome, {this.transfer});

  final TonTransferCreateOutcome outcome;
  final TonWalletTransfer? transfer;
}

enum TonTransferPrepareOutcome { prepared, invalidStatus }

enum TonTransferCompleteOutcome { completed, alreadyCompleted, invalidStatus }

class TonWalletTransferRepository {
  Database get _db => AppDatabase.instance;

  TonTransferCreateResult create({
    required String operationId,
    required String idempotencyKey,
    required String requestIdentity,
    required int buyerTelegramId,
    required String recipientAddress,
    required TonAmount amount,
    required UsdAmount price,
  }) {
    _db.execute('BEGIN IMMEDIATE;');
    try {
      final existing = findByIdempotencyKey(idempotencyKey);
      if (existing != null) {
        _db.execute('COMMIT;');
        return TonTransferCreateResult(
          existing.requestIdentity == requestIdentity
              ? TonTransferCreateOutcome.existing
              : TonTransferCreateOutcome.idempotencyConflict,
          transfer: existing,
        );
      }
      final now = DateTime.now().toUtc().toIso8601String();
      _db.execute(
        '''
        INSERT INTO ton_wallet_transfers (
          operation_id, idempotency_key, request_identity,
          buyer_telegram_id, recipient_address, amount_nano,
          price_usd_micros, status, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        ''',
        [
          operationId,
          idempotencyKey,
          requestIdentity,
          buyerTelegramId,
          recipientAddress,
          amount.nano,
          price.micros,
          TonWalletTransferStatus.created.databaseValue,
          now,
          now,
        ],
      );
      _db.execute('COMMIT;');
      return TonTransferCreateResult(
        TonTransferCreateOutcome.created,
        transfer: findByOperationId(operationId),
      );
    } catch (_) {
      _db.execute('ROLLBACK;');
      rethrow;
    }
  }

  TonTransferPrepareOutcome markPrepared({
    required String operationId,
    required String signedBoc,
    required String messageHash,
  }) {
    _db.execute('BEGIN IMMEDIATE;');
    try {
      final transfer = findByOperationId(operationId);
      if (transfer == null ||
          transfer.status != TonWalletTransferStatus.created) {
        _db.execute('ROLLBACK;');
        return TonTransferPrepareOutcome.invalidStatus;
      }
      final now = DateTime.now().toUtc().toIso8601String();
      _db.execute(
        '''
        UPDATE ton_wallet_transfers
        SET status = ?, signed_boc = ?, message_hash = ?,
            balance_reserved_at = NULL, updated_at = ?
        WHERE operation_id = ? AND status = ?;
        ''',
        [
          TonWalletTransferStatus.prepared.databaseValue,
          signedBoc,
          messageHash,
          now,
          operationId,
          TonWalletTransferStatus.created.databaseValue,
        ],
      );
      if (_db.updatedRows == 0) {
        _db.execute('ROLLBACK;');
        return TonTransferPrepareOutcome.invalidStatus;
      }
      _db.execute('COMMIT;');
      return TonTransferPrepareOutcome.prepared;
    } catch (_) {
      _db.execute('ROLLBACK;');
      rethrow;
    }
  }

  bool markPending({
    required String operationId,
    String? errorKind,
    String? errorDetail,
  }) {
    final now = DateTime.now().toUtc().toIso8601String();
    _db.execute(
      '''
      UPDATE ton_wallet_transfers
      SET status = ?, error_kind = ?, error_detail = ?, updated_at = ?
      WHERE operation_id = ? AND status IN (?, ?);
      ''',
      [
        TonWalletTransferStatus.pending.databaseValue,
        errorKind,
        _safeDetail(errorDetail),
        now,
        operationId,
        TonWalletTransferStatus.prepared.databaseValue,
        TonWalletTransferStatus.pending.databaseValue,
      ],
    );
    return _db.updatedRows > 0;
  }

  TonTransferCompleteOutcome markCompleted({
    required String operationId,
    String? txHash,
  }) {
    _db.execute('BEGIN IMMEDIATE;');
    try {
      final transfer = findByOperationId(operationId);
      if (transfer == null) {
        _db.execute('ROLLBACK;');
        return TonTransferCompleteOutcome.invalidStatus;
      }
      if (transfer.status == TonWalletTransferStatus.completed) {
        _db.execute('COMMIT;');
        return TonTransferCompleteOutcome.alreadyCompleted;
      }
      if (transfer.status != TonWalletTransferStatus.prepared &&
          transfer.status != TonWalletTransferStatus.pending) {
        _db.execute('ROLLBACK;');
        return TonTransferCompleteOutcome.invalidStatus;
      }
      final now = DateTime.now().toUtc().toIso8601String();
      _db.execute(
        '''
        UPDATE ton_wallet_transfers
        SET status = ?, tx_hash = COALESCE(?, tx_hash),
            error_kind = NULL, error_detail = NULL,
            completed_at = ?, updated_at = ?
        WHERE operation_id = ? AND status IN (?, ?);
        ''',
        [
          TonWalletTransferStatus.completed.databaseValue,
          txHash,
          now,
          now,
          operationId,
          TonWalletTransferStatus.prepared.databaseValue,
          TonWalletTransferStatus.pending.databaseValue,
        ],
      );
      if (_db.updatedRows == 0) {
        _db.execute('ROLLBACK;');
        return TonTransferCompleteOutcome.invalidStatus;
      }
      _db.execute(
        '''
        INSERT OR IGNORE INTO user_purchase_history (
          telegram_id, purchase_id, purchase_type, quantity, spent_usd,
          spent_usd_micros, purchased_at
        ) VALUES (?, ?, 'ton', ?, ?, ?, ?);
        ''',
        [
          transfer.buyerTelegramId,
          'ton_wallet:${transfer.operationId}',
          transfer.amount.nano / TonAmount.nanoPerTon,
          transfer.price.toLegacyDouble(),
          transfer.price.micros,
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
          transfer.buyerTelegramId,
          transfer.price.toLegacyDouble(),
          transfer.price.micros,
          now,
        ],
      );
      _db.execute('COMMIT;');
      return TonTransferCompleteOutcome.completed;
    } catch (_) {
      _db.execute('ROLLBACK;');
      rethrow;
    }
  }

  bool markFailed({
    required String operationId,
    required String errorKind,
    required String errorDetail,
  }) {
    _db.execute('BEGIN IMMEDIATE;');
    try {
      final transfer = findByOperationId(operationId);
      if (transfer == null || transfer.status.isFinal) {
        _db.execute('ROLLBACK;');
        return false;
      }
      final now = DateTime.now().toUtc().toIso8601String();
      _db.execute(
        '''
        UPDATE ton_wallet_transfers
        SET status = ?, error_kind = ?, error_detail = ?, updated_at = ?
        WHERE operation_id = ? AND status IN (?, ?, ?);
        ''',
        [
          TonWalletTransferStatus.failed.databaseValue,
          errorKind,
          _safeDetail(errorDetail),
          now,
          operationId,
          TonWalletTransferStatus.created.databaseValue,
          TonWalletTransferStatus.prepared.databaseValue,
          TonWalletTransferStatus.pending.databaseValue,
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

  TonWalletTransfer? findByOperationId(String operationId) {
    final rows = _db.select(
      'SELECT * FROM ton_wallet_transfers WHERE operation_id = ? LIMIT 1;',
      [operationId],
    );
    return rows.isEmpty ? null : TonWalletTransfer.fromMap(rows.first);
  }

  TonWalletTransfer? findByIdempotencyKey(String idempotencyKey) {
    final rows = _db.select(
      'SELECT * FROM ton_wallet_transfers WHERE idempotency_key = ? LIMIT 1;',
      [idempotencyKey],
    );
    return rows.isEmpty ? null : TonWalletTransfer.fromMap(rows.first);
  }

  List<TonWalletTransfer> findRecoverable({
    required Duration minimumAge,
    int limit = 20,
  }) {
    final cutoff = DateTime.now()
        .toUtc()
        .subtract(minimumAge)
        .toIso8601String();
    final rows = _db.select(
      '''
      SELECT * FROM ton_wallet_transfers
      WHERE status IN (?, ?)
        AND signed_boc IS NOT NULL
        AND message_hash IS NOT NULL
        AND updated_at <= ?
      ORDER BY updated_at ASC
      LIMIT ?;
      ''',
      [
        TonWalletTransferStatus.prepared.databaseValue,
        TonWalletTransferStatus.pending.databaseValue,
        cutoff,
        limit,
      ],
    );
    return rows.map(TonWalletTransfer.fromMap).toList(growable: false);
  }

  List<TonWalletTransfer> findStaleCreated({
    required Duration minimumAge,
    int limit = 20,
  }) {
    final cutoff = DateTime.now()
        .toUtc()
        .subtract(minimumAge)
        .toIso8601String();
    final rows = _db.select(
      '''
      SELECT * FROM ton_wallet_transfers
      WHERE status = ? AND updated_at <= ?
      ORDER BY updated_at ASC
      LIMIT ?;
      ''',
      [TonWalletTransferStatus.created.databaseValue, cutoff, limit],
    );
    return rows.map(TonWalletTransfer.fromMap).toList(growable: false);
  }
}

String? _safeDetail(String? value) {
  if (value == null) return null;
  final normalized = value.replaceAll(RegExp(r'[\r\n]+'), ' ').trim();
  return normalized.length <= 500 ? normalized : normalized.substring(0, 500);
}
