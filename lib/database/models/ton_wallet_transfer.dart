import 'package:pozzy_bot/database/models/ton_amount.dart';
import 'package:pozzy_bot/database/models/usd_amount.dart';

enum TonWalletTransferStatus {
  created,
  prepared,
  pending,
  completed,
  failed;

  String get databaseValue => name;

  bool get isFinal =>
      this == TonWalletTransferStatus.completed ||
      this == TonWalletTransferStatus.failed;

  static TonWalletTransferStatus fromDatabase(String value) =>
      TonWalletTransferStatus.values.firstWhere(
        (status) => status.databaseValue == value,
      );
}

class TonWalletTransfer {
  const TonWalletTransfer({
    required this.operationId,
    required this.idempotencyKey,
    required this.requestIdentity,
    required this.buyerTelegramId,
    required this.recipientAddress,
    required this.amount,
    required this.price,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.signedBoc,
    this.messageHash,
    this.txHash,
    this.errorKind,
    this.errorDetail,
    this.balanceReservedAt,
    this.completedAt,
  });

  factory TonWalletTransfer.fromMap(Map<String, Object?> row) {
    return TonWalletTransfer(
      operationId: row['operation_id'] as String,
      idempotencyKey: row['idempotency_key'] as String,
      requestIdentity: row['request_identity'] as String,
      buyerTelegramId: row['buyer_telegram_id'] as int,
      recipientAddress: row['recipient_address'] as String,
      amount: TonAmount.fromNano(row['amount_nano'] as int),
      price: UsdAmount.fromMicros(row['price_usd_micros'] as int),
      status: TonWalletTransferStatus.fromDatabase(row['status'] as String),
      signedBoc: row['signed_boc'] as String?,
      messageHash: row['message_hash'] as String?,
      txHash: row['tx_hash'] as String?,
      errorKind: row['error_kind'] as String?,
      errorDetail: row['error_detail'] as String?,
      balanceReservedAt: _date(row['balance_reserved_at']),
      completedAt: _date(row['completed_at']),
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }

  final String operationId;
  final String idempotencyKey;
  final String requestIdentity;
  final int buyerTelegramId;
  final String recipientAddress;
  final TonAmount amount;
  final UsdAmount price;
  final TonWalletTransferStatus status;
  final String? signedBoc;
  final String? messageHash;
  final String? txHash;
  final String? errorKind;
  final String? errorDetail;
  final DateTime? balanceReservedAt;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
}

DateTime? _date(Object? value) {
  if (value == null) return null;
  return DateTime.parse(value as String);
}
