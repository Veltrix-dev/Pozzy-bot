import 'package:pozzy_bot/app/labels/message/gift/gift_purchase_text.dart';
import 'package:pozzy_bot/handler/reply_handler.dart';
import 'package:pozzy_bot/services/gift/gift_catalog.dart';
import 'package:pozzy_bot/services/gift/gift_purchase_service.dart';
import 'package:televerse/televerse.dart';

class GiftPurchaseHandler {
  GiftPurchaseHandler({
    required ReplyHandler reply,
    required GiftPurchaseService purchases,
  }) : _reply = reply,
       _purchases = purchases;

  final ReplyHandler _reply;
  final GiftPurchaseService _purchases;

  Future<GiftPurchaseResult> deliverPaidGift({
    required ChatID chatId,
    required String paymentId,
    required int buyerTelegramId,
    required GiftKind kind,
    required String recipient,
    int? recipientTelegramId,
  }) async {
    await _reply.sendProcessingStatus(chatId, GiftPurchaseText.sendingGift);

    final result = await _purchases.deliverPaidGift(
      paymentId: paymentId,
      buyerTelegramId: buyerTelegramId,
      kind: kind,
      recipient: recipient,
      recipientTelegramId: recipientTelegramId,
    );
    await _sendOutcome(chatId, result.outcome);
    return result;
  }

  Future<void> _sendOutcome(ChatID chatId, GiftPurchaseOutcome outcome) async {
    final text = switch (outcome) {
      GiftPurchaseOutcome.giftSent => GiftPurchaseText.giftSent,
      GiftPurchaseOutcome.invalidRecipient ||
      GiftPurchaseOutcome.recipientNotFound =>
        GiftPurchaseText.invalidRecipient,
      GiftPurchaseOutcome.userbotUnavailable =>
        GiftPurchaseText.userbotUnavailable,
      GiftPurchaseOutcome.botStarsInsufficient ||
      GiftPurchaseOutcome.giftUnavailable ||
      GiftPurchaseOutcome.floodWait ||
      GiftPurchaseOutcome.giftFailed => GiftPurchaseText.giftFailed,
      GiftPurchaseOutcome.alreadyCompleted ||
      GiftPurchaseOutcome.purchaseInProgress ||
      GiftPurchaseOutcome.paymentConflict ||
      GiftPurchaseOutcome.invalidPaymentId ||
      GiftPurchaseOutcome.pendingConfirmation => null,
    };
    if (text != null) {
      await _reply.sendText(chatId, text);
    }
  }
}
