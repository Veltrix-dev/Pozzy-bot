import 'package:pozzy_bot/database/models/fragment_order_status.dart';
import 'package:pozzy_bot/database/models/fragment_purchase_type.dart';
import 'package:pozzy_bot/database/models/ton_amount.dart';
import 'package:pozzy_bot/database/models/usd_amount.dart';

class FragmentOrder {
  const FragmentOrder({
    required this.orderId,
    required this.idempotencyKey,
    required this.buyerTelegramId,
    required this.purchaseType,
    required this.quantityUnits,
    required this.price,
    required this.recipientUsername,
    required this.status,
    required this.attemptCount,
    required this.createdAt,
    required this.updatedAt,
    this.externalReference,
    this.apiResponseJson,
    this.errorCode,
    this.errorDetail,
    this.balanceReservedAt,
    this.completedAt,
  });

  factory FragmentOrder.fromMap(Map<String, Object?> row) {
    return FragmentOrder(
      orderId: row['order_id'] as String,
      idempotencyKey: row['idempotency_key'] as String,
      buyerTelegramId: row['buyer_telegram_id'] as int,
      purchaseType: FragmentPurchaseType.fromDatabase(
        row['purchase_type'] as String,
      ),
      quantityUnits: row['quantity_units'] as int,
      price: UsdAmount.fromMicros(row['price_usd_micros'] as int),
      recipientUsername: row['recipient_username'] as String,
      status: FragmentOrderStatus.fromDatabase(row['status'] as String),
      attemptCount: row['attempt_count'] as int,
      externalReference: row['external_reference'] as String?,
      apiResponseJson: row['api_response_json'] as String?,
      errorCode: row['error_code'] as String?,
      errorDetail: row['error_detail'] as String?,
      balanceReservedAt: _date(row['balance_reserved_at']),
      completedAt: _date(row['completed_at']),
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }

  final String orderId;
  final String idempotencyKey;
  final int buyerTelegramId;
  final FragmentPurchaseType purchaseType;
  final int quantityUnits;
  final UsdAmount price;
  final String recipientUsername;
  final FragmentOrderStatus status;
  final int attemptCount;
  final String? externalReference;
  final String? apiResponseJson;
  final String? errorCode;
  final String? errorDetail;
  final DateTime? balanceReservedAt;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  int get starsAmount => quantityUnits;

  int get premiumMonths => quantityUnits;

  TonAmount get tonAmount => TonAmount.fromNano(quantityUnits);
}

DateTime? _date(Object? value) {
  if (value == null) return null;
  return DateTime.parse(value as String);
}
