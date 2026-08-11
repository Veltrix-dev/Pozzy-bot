class GiftPurchase {
  GiftPurchase({
    required this.paymentId,
    required this.buyerTelegramId,
    required this.giftKind,
    required this.giftId,
    required this.priceUsd,
    required this.recipient,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.recipientTelegramId,
    this.errorCode,
    this.errorDetail,
  });

  factory GiftPurchase.fromMap(Map<String, Object?> row) {
    return GiftPurchase(
      paymentId: row['payment_id'] as String,
      buyerTelegramId: row['buyer_telegram_id'] as int,
      giftKind: row['gift_kind'] as String,
      giftId: row['gift_id'] as String,
      priceUsd: (row['price_usd'] as num).toDouble(),
      recipient: row['recipient'] as String,
      recipientTelegramId: row['recipient_telegram_id'] as int?,
      status: row['status'] as String,
      errorCode: row['error_code'] as String?,
      errorDetail: row['error_detail'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }

  final String paymentId;
  final int buyerTelegramId;
  final String giftKind;
  final String giftId;
  final double priceUsd;
  final String recipient;
  final int? recipientTelegramId;
  final String status;
  final String? errorCode;
  final String? errorDetail;
  final DateTime createdAt;
  final DateTime updatedAt;
}
