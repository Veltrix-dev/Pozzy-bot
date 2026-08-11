import 'package:pozzy_bot/database/repositories/gift_purchase_repository.dart';
import 'package:pozzy_bot/database/models/gift_purchase.dart';
import 'package:pozzy_bot/database/models/gift_purchase_statuses.dart';
import 'package:pozzy_bot/database/repositories/user_repositories.dart';
import 'package:pozzy_bot/services/gift/gift_catalog.dart';
import 'package:pozzy_bot/services/referral/referral_service.dart';
import 'package:pozzy_bot/services/userbot/userbot_gift_client.dart';
import 'package:pozzy_bot/services/userbot/userbot_gift_result.dart';
import 'package:pozzy_bot/utils/bot_log.dart';

enum GiftPurchaseOutcome {
  giftSent,
  alreadyCompleted,
  purchaseInProgress,
  paymentConflict,
  invalidPaymentId,
  invalidRecipient,
  userbotUnavailable,
  botStarsInsufficient,
  giftUnavailable,
  recipientNotFound,
  floodWait,
  pendingConfirmation,
  giftFailed,
}

class GiftPurchaseResult {
  const GiftPurchaseResult(this.outcome, {this.floodWaitSeconds});

  final GiftPurchaseOutcome outcome;
  final int? floodWaitSeconds;
}

class GiftPurchaseService {
  GiftPurchaseService({
    required GiftPurchaseRepository purchases,
    required UserRepositories users,
    required GiftDeliveryClient delivery,
    required ReferralService referrals,
  }) : _purchases = purchases,
       _users = users,
       _delivery = delivery,
       _referrals = referrals;

  final GiftPurchaseRepository _purchases;
  final UserRepositories _users;
  final GiftDeliveryClient _delivery;
  final ReferralService _referrals;

  /// Future payment integrations call this method only after the payment
  /// provider has confirmed [paymentId] as paid.
  Future<GiftPurchaseResult> deliverPaidGift({
    required String paymentId,
    required int buyerTelegramId,
    required GiftKind kind,
    required String recipient,
    int? recipientTelegramId,
  }) async {
    final normalizedPaymentId = paymentId.trim();
    if (normalizedPaymentId.isEmpty) {
      return const GiftPurchaseResult(GiftPurchaseOutcome.invalidPaymentId);
    }

    final normalizedRecipient = _normalizeRecipient(recipient);
    if (normalizedRecipient == null) {
      return const GiftPurchaseResult(GiftPurchaseOutcome.invalidRecipient);
    }
    if (_users.findByTelegramId(buyerTelegramId) == null) {
      _users.insert(
        telegramId: buyerTelegramId,
        username: null,
        role: _users.roleForNewUser(buyerTelegramId),
      );
    }

    final product = GiftCatalog.productFor(kind);
    final existing = _purchases.findByPaymentId(normalizedPaymentId);
    if (existing != null) {
      if (!_matchesPaidProduct(
        existing,
        buyerTelegramId: buyerTelegramId,
        kind: kind,
        giftId: product.telegramGiftId,
        priceUsd: product.priceUsd,
      )) {
        return const GiftPurchaseResult(GiftPurchaseOutcome.paymentConflict);
      }
      if (existing.status == GiftPurchaseStatuses.completed) {
        await _creditReferralCommission(existing);
        return const GiftPurchaseResult(GiftPurchaseOutcome.alreadyCompleted);
      }
      if (existing.status == GiftPurchaseStatuses.processing) {
        return const GiftPurchaseResult(GiftPurchaseOutcome.purchaseInProgress);
      }
    }

    if (!await _delivery.isHealthy()) {
      return const GiftPurchaseResult(GiftPurchaseOutcome.userbotUnavailable);
    }

    final begin = _purchases.tryBeginPaidDelivery(
      paymentId: normalizedPaymentId,
      buyerTelegramId: buyerTelegramId,
      giftKind: kind.name,
      giftId: product.telegramGiftId,
      priceUsd: product.priceUsd,
      recipient: normalizedRecipient,
      recipientTelegramId: recipientTelegramId,
    );
    switch (begin) {
      case GiftBeginDeliveryResult.alreadyCompleted:
        final completed = _purchases.findByPaymentId(normalizedPaymentId);
        if (completed != null) {
          await _creditReferralCommission(completed);
        }
        return const GiftPurchaseResult(GiftPurchaseOutcome.alreadyCompleted);
      case GiftBeginDeliveryResult.alreadyProcessing:
        return const GiftPurchaseResult(GiftPurchaseOutcome.purchaseInProgress);
      case GiftBeginDeliveryResult.paymentConflict:
        return const GiftPurchaseResult(GiftPurchaseOutcome.paymentConflict);
      case GiftBeginDeliveryResult.started:
        break;
    }

    final delivery = await _delivery.sendGift(
      giftId: product.telegramGiftId,
      recipient: normalizedRecipient,
    );
    if (delivery.success) {
      final completed = _purchases.markCompletedAndRecordStatistics(
        normalizedPaymentId,
      );
      if (completed == null) {
        return const GiftPurchaseResult(GiftPurchaseOutcome.purchaseInProgress);
      }

      await _creditReferralCommission(completed);
      return const GiftPurchaseResult(GiftPurchaseOutcome.giftSent);
    }

    if (delivery.error == UserbotGiftError.timeout) {
      BotLog.error(
        'gift delivery confirmation pending payment=$normalizedPaymentId '
        'detail=${delivery.detail}',
      );
      return const GiftPurchaseResult(GiftPurchaseOutcome.pendingConfirmation);
    }

    BotLog.error(
      'gift delivery failed payment=$normalizedPaymentId '
      'buyer=$buyerTelegramId gift=${kind.name} '
      'gift_id=${product.telegramGiftId} '
      'error=${delivery.error?.name ?? 'unknown'} '
      'detail=${delivery.detail ?? 'none'}',
    );
    _purchases.markFailed(
      normalizedPaymentId,
      errorCode: delivery.error?.name,
      errorDetail: delivery.detail,
    );
    return _mapFailure(delivery);
  }

  GiftPurchaseResult _mapFailure(UserbotGiftResult delivery) {
    if (delivery.error == UserbotGiftError.floodWait) {
      return GiftPurchaseResult(
        GiftPurchaseOutcome.floodWait,
        floodWaitSeconds: delivery.waitSeconds,
      );
    }
    final outcome = switch (delivery.error) {
      UserbotGiftError.balanceTooLow =>
        GiftPurchaseOutcome.botStarsInsufficient,
      UserbotGiftError.giftIdNotFound ||
      UserbotGiftError.stargiftUsageLimited ||
      UserbotGiftError.stargiftInvalid => GiftPurchaseOutcome.giftUnavailable,
      UserbotGiftError.peerIdInvalid ||
      UserbotGiftError.usernameInvalid => GiftPurchaseOutcome.recipientNotFound,
      UserbotGiftError.userbotNotConnected =>
        GiftPurchaseOutcome.userbotUnavailable,
      UserbotGiftError.timeout => GiftPurchaseOutcome.pendingConfirmation,
      UserbotGiftError.floodWait ||
      UserbotGiftError.unknown ||
      null => GiftPurchaseOutcome.giftFailed,
    };
    return GiftPurchaseResult(outcome);
  }

  String? _normalizeRecipient(String recipient) {
    var value = recipient.trim();
    if (value.startsWith('@')) value = value.substring(1);
    if (RegExp(r'^\d+$').hasMatch(value)) return value;
    if (!RegExp(r'^[A-Za-z][A-Za-z0-9_]{4,31}$').hasMatch(value)) {
      return null;
    }
    return value;
  }

  bool _matchesPaidProduct(
    GiftPurchase purchase, {
    required int buyerTelegramId,
    required GiftKind kind,
    required String giftId,
    required double priceUsd,
  }) {
    return purchase.buyerTelegramId == buyerTelegramId &&
        purchase.giftKind == kind.name &&
        purchase.giftId == giftId &&
        (purchase.priceUsd - priceUsd).abs() < 0.000001;
  }

  Future<void> _creditReferralCommission(GiftPurchase purchase) async {
    try {
      await _referrals.creditPurchaseCommission(
        referralTelegramId: purchase.buyerTelegramId,
        purchaseId: 'gift:${purchase.paymentId}',
        purchaseAmount: purchase.priceUsd,
      );
    } catch (error, stackTrace) {
      BotLog.error(
        'gift referral commission failed payment=${purchase.paymentId}: '
        '$error\n$stackTrace',
      );
    }
  }
}
