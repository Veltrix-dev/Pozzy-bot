import 'dart:convert';
import 'dart:math';

import 'package:pozzy_bot/database/models/fragment_order.dart';
import 'package:pozzy_bot/database/models/fragment_order_status.dart';
import 'package:pozzy_bot/database/models/fragment_purchase_type.dart';
import 'package:pozzy_bot/database/models/ton_amount.dart';
import 'package:pozzy_bot/database/repositories/fragment_order_repository.dart';
import 'package:pozzy_bot/database/repositories/user_repositories.dart';
import 'package:pozzy_bot/services/fragment/fragment_api_exception.dart';
import 'package:pozzy_bot/services/fragment/fragment_api_models.dart';
import 'package:pozzy_bot/services/fragment/fragment_gateway.dart';
import 'package:pozzy_bot/services/fragment/fragment_pricing_service.dart';
import 'package:pozzy_bot/services/referral/referral_service.dart';
import 'package:pozzy_bot/utils/bot_log.dart';
import 'package:sqlite3/sqlite3.dart';

enum FragmentPurchaseOutcome {
  orderCreated,
  completed,
  alreadyCompleted,
  pendingConfirmation,
  purchaseInProgress,
  insufficientBalance,
  invalidTelegramUsername,
  invalidTelegramId,
  invalidStarsAmount,
  invalidPremiumDuration,
  invalidTonAmount,
  buyerNotFound,
  idempotencyConflict,
  orderNotFound,
  invalidOrderState,
  serviceUnavailable,
  apiRejected,
  configurationError,
  databaseError,
  failed,
  cancelled,
}

class FragmentPurchaseResult {
  const FragmentPurchaseResult({
    required this.outcome,
    this.order,
    this.errorKind,
    this.message,
  });

  final FragmentPurchaseOutcome outcome;
  final FragmentOrder? order;
  final FragmentApiErrorKind? errorKind;
  final String? message;
}

class FragmentPurchaseService {
  FragmentPurchaseService({
    required FragmentOrderRepository orders,
    required UserRepositories users,
    required FragmentGateway gateway,
    required FragmentPricingService pricing,
    ReferralService? referrals,
  }) : _orders = orders,
       _users = users,
       _gateway = gateway,
       _pricing = pricing,
       _referrals = referrals;

  final FragmentOrderRepository _orders;
  final UserRepositories _users;
  final FragmentGateway _gateway;
  final FragmentPricingService _pricing;
  final ReferralService? _referrals;

  Future<FragmentPurchaseResult> purchaseStars({
    required String idempotencyKey,
    required int buyerTelegramId,
    required String recipientUsername,
    required int amount,
  }) async {
    if (amount < 50 || amount > 1000000) {
      return const FragmentPurchaseResult(
        outcome: FragmentPurchaseOutcome.invalidStarsAmount,
      );
    }
    final existing = await _findExistingRequest(
      idempotencyKey: idempotencyKey,
      buyerTelegramId: buyerTelegramId,
      recipientUsername: recipientUsername,
      purchaseType: FragmentPurchaseType.stars,
      quantityUnits: amount,
    );
    if (existing != null) return existing;
    try {
      final quote = await _pricing.quoteStars(amount);
      return _createAndExecute(
        idempotencyKey: idempotencyKey,
        buyerTelegramId: buyerTelegramId,
        recipientUsername: recipientUsername,
        quote: quote,
      );
    } on FragmentApiException catch (error) {
      return _configurationFailure(error);
    }
  }

  Future<FragmentPurchaseResult> purchasePremium({
    required String idempotencyKey,
    required int buyerTelegramId,
    required String recipientUsername,
    required int months,
  }) async {
    if (months != 3 && months != 6 && months != 12) {
      return const FragmentPurchaseResult(
        outcome: FragmentPurchaseOutcome.invalidPremiumDuration,
      );
    }
    final existing = await _findExistingRequest(
      idempotencyKey: idempotencyKey,
      buyerTelegramId: buyerTelegramId,
      recipientUsername: recipientUsername,
      purchaseType: FragmentPurchaseType.premium,
      quantityUnits: months,
    );
    if (existing != null) return existing;
    try {
      final quote = _pricing.quotePremium(months);
      return _createAndExecute(
        idempotencyKey: idempotencyKey,
        buyerTelegramId: buyerTelegramId,
        recipientUsername: recipientUsername,
        quote: quote,
      );
    } on FragmentApiException catch (error) {
      return _configurationFailure(error);
    }
  }

  Future<FragmentPurchaseResult> purchaseTon({
    required String idempotencyKey,
    required int buyerTelegramId,
    required String recipientUsername,
    required String amount,
  }) async {
    TonAmount tonAmount;
    try {
      tonAmount = TonAmount.parse(amount);
    } on FormatException {
      return const FragmentPurchaseResult(
        outcome: FragmentPurchaseOutcome.invalidTonAmount,
      );
    }
    if (tonAmount.isZero) {
      return const FragmentPurchaseResult(
        outcome: FragmentPurchaseOutcome.invalidTonAmount,
      );
    }
    final existing = await _findExistingRequest(
      idempotencyKey: idempotencyKey,
      buyerTelegramId: buyerTelegramId,
      recipientUsername: recipientUsername,
      purchaseType: FragmentPurchaseType.ton,
      quantityUnits: tonAmount.nano,
    );
    if (existing != null) return existing;
    try {
      final quote = _pricing.quoteTon(tonAmount);
      return _createAndExecute(
        idempotencyKey: idempotencyKey,
        buyerTelegramId: buyerTelegramId,
        recipientUsername: recipientUsername,
        quote: quote,
      );
    } on FragmentApiException catch (error) {
      return _configurationFailure(error);
    }
  }

  Future<FragmentPurchaseResult> createOrder({
    required String idempotencyKey,
    required int buyerTelegramId,
    required String recipientUsername,
    required FragmentPriceQuote quote,
  }) async {
    final inputFailure = _validateCommonInput(
      idempotencyKey: idempotencyKey,
      buyerTelegramId: buyerTelegramId,
      recipientUsername: recipientUsername,
    );
    if (inputFailure != null) return inputFailure;
    if (_users.findByTelegramId(buyerTelegramId) == null) {
      return const FragmentPurchaseResult(
        outcome: FragmentPurchaseOutcome.buyerNotFound,
      );
    }

    final normalizedUsername = _normalizeUsername(recipientUsername);
    try {
      final created = _orders.create(
        orderId: _newOrderId(),
        idempotencyKey: idempotencyKey.trim(),
        buyerTelegramId: buyerTelegramId,
        purchaseType: quote.purchaseType,
        quantityUnits: quote.quantityUnits,
        price: quote.price,
        recipientUsername: normalizedUsername,
      );
      if (created.outcome == FragmentOrderCreateOutcome.idempotencyConflict) {
        return FragmentPurchaseResult(
          outcome: FragmentPurchaseOutcome.idempotencyConflict,
          order: created.order,
        );
      }
      final order = created.order!;
      if (created.outcome == FragmentOrderCreateOutcome.created) {
        BotLog.event(
          'fragment order_created order=${order.orderId} '
          'buyer=${order.buyerTelegramId} type=${order.purchaseType.name}',
        );
        return FragmentPurchaseResult(
          outcome: FragmentPurchaseOutcome.orderCreated,
          order: order,
        );
      }
      return _resultForExisting(order);
    } on SqliteException catch (error, stackTrace) {
      BotLog.error(
        'fragment order_create_db_failed buyer=$buyerTelegramId '
        'error=$error\n$stackTrace',
      );
      return const FragmentPurchaseResult(
        outcome: FragmentPurchaseOutcome.databaseError,
      );
    }
  }

  Future<FragmentPurchaseResult> executeOrder(String orderId) async {
    try {
      return await _executeOrder(orderId.trim());
    } on SqliteException catch (error, stackTrace) {
      BotLog.error(
        'fragment order_db_failed order=$orderId error=$error\n$stackTrace',
      );
      final order = _safeFind(orderId);
      return FragmentPurchaseResult(
        outcome: order?.status == FragmentOrderStatus.processing
            ? FragmentPurchaseOutcome.pendingConfirmation
            : FragmentPurchaseOutcome.databaseError,
        order: order,
      );
    } catch (error, stackTrace) {
      BotLog.error(
        'fragment order_internal_failed order=$orderId error=$error\n$stackTrace',
      );
      final order = _safeFind(orderId);
      if (order?.status == FragmentOrderStatus.processing) {
        _orders.markProcessingUncertain(
          orderId: orderId,
          errorCode: 'internal_error',
          errorDetail: error.toString(),
        );
        return FragmentPurchaseResult(
          outcome: FragmentPurchaseOutcome.pendingConfirmation,
          order: _safeFind(orderId),
        );
      }
      return FragmentPurchaseResult(
        outcome: FragmentPurchaseOutcome.failed,
        order: order,
      );
    }
  }

  FragmentOrder? getOrder(String orderId) => _orders.findByOrderId(orderId);

  bool cancelOrder(String orderId) => _orders.cancelCreated(orderId);

  List<FragmentOrder> restorePendingOrders({
    Duration minimumAge = Duration.zero,
  }) {
    final pending = _orders.findProcessingOlderThan(minimumAge);
    for (final order in pending) {
      BotLog.error(
        'fragment order_recovery_required order=${order.orderId} '
        'buyer=${order.buyerTelegramId} type=${order.purchaseType.name} '
        'attempts=${order.attemptCount}',
      );
    }
    return pending;
  }

  Future<FragmentPurchaseResult> _createAndExecute({
    required String idempotencyKey,
    required int buyerTelegramId,
    required String recipientUsername,
    required FragmentPriceQuote quote,
  }) async {
    final created = await createOrder(
      idempotencyKey: idempotencyKey,
      buyerTelegramId: buyerTelegramId,
      recipientUsername: recipientUsername,
      quote: quote,
    );
    if (created.outcome != FragmentPurchaseOutcome.orderCreated) {
      return created;
    }
    return executeOrder(created.order!.orderId);
  }

  Future<FragmentPurchaseResult> _executeOrder(String orderId) async {
    final order = _orders.findByOrderId(orderId);
    if (order == null) {
      return const FragmentPurchaseResult(
        outcome: FragmentPurchaseOutcome.orderNotFound,
      );
    }
    final existing = _resultForExisting(order);
    if (order.status != FragmentOrderStatus.created) {
      if (existing.outcome == FragmentPurchaseOutcome.alreadyCompleted) {
        await _creditReferral(order);
      }
      return existing;
    }

    try {
      final health = await _gateway.getHealth();
      if (!health.healthy || !health.cookieExists || !health.cookieValid) {
        _orders.recordCreatedError(
          orderId: order.orderId,
          errorCode: 'service_unhealthy',
          errorDetail: 'Fragment API or Fragment cookie is unavailable',
        );
        return FragmentPurchaseResult(
          outcome: FragmentPurchaseOutcome.serviceUnavailable,
          order: _orders.findByOrderId(order.orderId),
        );
      }
    } on FragmentApiException catch (error) {
      _orders.recordCreatedError(
        orderId: order.orderId,
        errorCode: error.kind.name,
        errorDetail: error.message,
      );
      return FragmentPurchaseResult(
        outcome: FragmentPurchaseOutcome.serviceUnavailable,
        order: _orders.findByOrderId(order.orderId),
        errorKind: error.kind,
        message: error.message,
      );
    }

    try {
      final recipient = await _gateway.searchUser(order.recipientUsername);
      if (_normalizeUsername(recipient.username).toLowerCase() !=
          order.recipientUsername.toLowerCase()) {
        _orders.markFailedAndRefund(
          orderId: order.orderId,
          errorCode: 'recipient_mismatch',
          errorDetail: 'Fragment returned another recipient',
        );
        return FragmentPurchaseResult(
          outcome: FragmentPurchaseOutcome.invalidTelegramUsername,
          order: _orders.findByOrderId(order.orderId),
        );
      }
    } on FragmentApiException catch (error) {
      final rejected =
          error.kind == FragmentApiErrorKind.httpClient ||
          error.kind == FragmentApiErrorKind.rejected;
      if (rejected) {
        _orders.markFailedAndRefund(
          orderId: order.orderId,
          errorCode: error.kind.name,
          errorDetail: error.message,
        );
      } else {
        _orders.recordCreatedError(
          orderId: order.orderId,
          errorCode: error.kind.name,
          errorDetail: error.message,
        );
      }
      return FragmentPurchaseResult(
        outcome: rejected
            ? FragmentPurchaseOutcome.invalidTelegramUsername
            : FragmentPurchaseOutcome.serviceUnavailable,
        order: _orders.findByOrderId(order.orderId),
        errorKind: error.kind,
        message: error.message,
      );
    }

    final begin = _orders.tryBeginProcessing(order.orderId);
    switch (begin) {
      case FragmentOrderBeginOutcome.insufficientBalance:
        return FragmentPurchaseResult(
          outcome: FragmentPurchaseOutcome.insufficientBalance,
          order: _orders.findByOrderId(order.orderId),
        );
      case FragmentOrderBeginOutcome.alreadyProcessing:
        return FragmentPurchaseResult(
          outcome: FragmentPurchaseOutcome.purchaseInProgress,
          order: _orders.findByOrderId(order.orderId),
        );
      case FragmentOrderBeginOutcome.alreadyCompleted:
        final completed = _orders.findByOrderId(order.orderId)!;
        await _creditReferral(completed);
        return FragmentPurchaseResult(
          outcome: FragmentPurchaseOutcome.alreadyCompleted,
          order: completed,
        );
      case FragmentOrderBeginOutcome.notFound:
        return const FragmentPurchaseResult(
          outcome: FragmentPurchaseOutcome.orderNotFound,
        );
      case FragmentOrderBeginOutcome.invalidStatus:
        return FragmentPurchaseResult(
          outcome: FragmentPurchaseOutcome.invalidOrderState,
          order: _orders.findByOrderId(order.orderId),
        );
      case FragmentOrderBeginOutcome.started:
        break;
    }

    BotLog.event(
      'fragment request_started order=${order.orderId} '
      'buyer=${order.buyerTelegramId} type=${order.purchaseType.name}',
    );
    FragmentPurchaseReceipt receipt;
    try {
      receipt = await _sendPurchase(order);
    } on FragmentApiException catch (error) {
      return _handlePurchaseApiError(order, error);
    }

    if (!_receiptMatches(order, receipt)) {
      _orders.markProcessingUncertain(
        orderId: order.orderId,
        errorCode: 'response_mismatch',
        errorDetail: 'Fragment response does not match the order',
      );
      BotLog.error('fragment response_mismatch order=${order.orderId}');
      return FragmentPurchaseResult(
        outcome: FragmentPurchaseOutcome.pendingConfirmation,
        order: _orders.findByOrderId(order.orderId),
      );
    }

    FragmentOrder? completed;
    try {
      completed = _orders.markCompleted(
        orderId: order.orderId,
        apiResponseJson: jsonEncode(receipt.toJson()),
        externalReference: receipt.externalReference,
      );
    } on SqliteException catch (error) {
      _orders.markProcessingUncertain(
        orderId: order.orderId,
        errorCode: 'completion_persist_failed',
        errorDetail: error.toString(),
      );
      rethrow;
    }
    if (completed == null) {
      return FragmentPurchaseResult(
        outcome: FragmentPurchaseOutcome.purchaseInProgress,
        order: _orders.findByOrderId(order.orderId),
      );
    }

    BotLog.event(
      'fragment order_completed order=${completed.orderId} '
      'buyer=${completed.buyerTelegramId} type=${completed.purchaseType.name} '
      'external_id=${completed.externalReference ?? 'not_provided'}',
    );
    await _creditReferral(completed);
    return FragmentPurchaseResult(
      outcome: FragmentPurchaseOutcome.completed,
      order: completed,
    );
  }

  Future<FragmentPurchaseReceipt> _sendPurchase(FragmentOrder order) {
    return switch (order.purchaseType) {
      FragmentPurchaseType.stars => _gateway.buyStars(
        recipient: order.recipientUsername,
        amount: order.starsAmount,
      ),
      FragmentPurchaseType.premium => _gateway.buyPremium(
        recipient: order.recipientUsername,
        months: order.premiumMonths,
      ),
      FragmentPurchaseType.ton => _gateway.addTon(
        recipient: order.recipientUsername,
        amount: order.tonAmount,
      ),
    };
  }

  FragmentPurchaseResult _handlePurchaseApiError(
    FragmentOrder order,
    FragmentApiException error,
  ) {
    BotLog.error(
      'fragment request_failed order=${order.orderId} '
      'type=${order.purchaseType.name} kind=${error.kind.name} '
      'status=${error.statusCode ?? 'none'} uncertain=${error.executionUncertain}',
    );
    if (error.executionUncertain) {
      _orders.markProcessingUncertain(
        orderId: order.orderId,
        errorCode: error.kind.name,
        errorDetail: error.message,
      );
      return FragmentPurchaseResult(
        outcome: FragmentPurchaseOutcome.pendingConfirmation,
        order: _orders.findByOrderId(order.orderId),
        errorKind: error.kind,
        message: error.message,
      );
    }

    _orders.markFailedAndRefund(
      orderId: order.orderId,
      errorCode: error.kind.name,
      errorDetail: error.message,
    );
    final outcome = switch (error.kind) {
      FragmentApiErrorKind.configuration =>
        FragmentPurchaseOutcome.configurationError,
      FragmentApiErrorKind.httpClient ||
      FragmentApiErrorKind.rejected => FragmentPurchaseOutcome.apiRejected,
      _ => FragmentPurchaseOutcome.failed,
    };
    return FragmentPurchaseResult(
      outcome: outcome,
      order: _orders.findByOrderId(order.orderId),
      errorKind: error.kind,
      message: error.message,
    );
  }

  bool _receiptMatches(FragmentOrder order, FragmentPurchaseReceipt receipt) {
    return receipt.purchaseType == order.purchaseType &&
        receipt.deliveredUnits == order.quantityUnits &&
        _normalizeUsername(receipt.username).toLowerCase() ==
            order.recipientUsername.toLowerCase();
  }

  Future<void> _creditReferral(FragmentOrder order) async {
    try {
      await _referrals?.creditPurchaseCommissionExact(
        referralTelegramId: order.buyerTelegramId,
        purchaseId: 'fragment:${order.orderId}',
        purchaseAmount: order.price,
      );
    } catch (error, stackTrace) {
      BotLog.error(
        'fragment referral_failed order=${order.orderId} '
        'error=$error\n$stackTrace',
      );
    }
  }

  Future<FragmentPurchaseResult?> _findExistingRequest({
    required String idempotencyKey,
    required int buyerTelegramId,
    required String recipientUsername,
    required FragmentPurchaseType purchaseType,
    required int quantityUnits,
  }) async {
    final key = idempotencyKey.trim();
    if (!RegExp(r'^[A-Za-z0-9._:-]{1,128}$').hasMatch(key)) return null;

    try {
      final existing = _orders.findByIdempotencyKey(key);
      if (existing == null) return null;
      final matches =
          existing.buyerTelegramId == buyerTelegramId &&
          existing.purchaseType == purchaseType &&
          existing.quantityUnits == quantityUnits &&
          existing.recipientUsername.toLowerCase() ==
              _normalizeUsername(recipientUsername).toLowerCase();
      if (!matches) {
        return FragmentPurchaseResult(
          outcome: FragmentPurchaseOutcome.idempotencyConflict,
          order: existing,
        );
      }
      if (existing.status == FragmentOrderStatus.completed) {
        await _creditReferral(existing);
      }
      return _resultForExisting(existing);
    } on SqliteException catch (error, stackTrace) {
      BotLog.error(
        'fragment idempotency_lookup_failed key_length=${key.length} '
        'error=$error\n$stackTrace',
      );
      return const FragmentPurchaseResult(
        outcome: FragmentPurchaseOutcome.databaseError,
      );
    }
  }

  FragmentPurchaseResult? _validateCommonInput({
    required String idempotencyKey,
    required int buyerTelegramId,
    required String recipientUsername,
  }) {
    if (buyerTelegramId <= 0) {
      return const FragmentPurchaseResult(
        outcome: FragmentPurchaseOutcome.invalidTelegramId,
      );
    }
    final key = idempotencyKey.trim();
    if (!RegExp(r'^[A-Za-z0-9._:-]{1,128}$').hasMatch(key)) {
      return const FragmentPurchaseResult(
        outcome: FragmentPurchaseOutcome.invalidOrderState,
        message: 'Invalid idempotency key',
      );
    }
    final username = _normalizeUsername(recipientUsername);
    if (RegExp(r'^\d+$').hasMatch(username)) {
      return const FragmentPurchaseResult(
        outcome: FragmentPurchaseOutcome.invalidTelegramId,
      );
    }
    if (!RegExp(r'^[A-Za-z][A-Za-z0-9_]{4,31}$').hasMatch(username)) {
      return const FragmentPurchaseResult(
        outcome: FragmentPurchaseOutcome.invalidTelegramUsername,
      );
    }
    return null;
  }

  FragmentPurchaseResult _resultForExisting(FragmentOrder order) {
    final outcome = switch (order.status) {
      FragmentOrderStatus.created => FragmentPurchaseOutcome.orderCreated,
      FragmentOrderStatus.processing =>
        FragmentPurchaseOutcome.pendingConfirmation,
      FragmentOrderStatus.completed => FragmentPurchaseOutcome.alreadyCompleted,
      FragmentOrderStatus.failed => FragmentPurchaseOutcome.failed,
      FragmentOrderStatus.cancelled => FragmentPurchaseOutcome.cancelled,
    };
    return FragmentPurchaseResult(outcome: outcome, order: order);
  }

  FragmentPurchaseResult _configurationFailure(FragmentApiException error) {
    return FragmentPurchaseResult(
      outcome: error.kind == FragmentApiErrorKind.configuration
          ? FragmentPurchaseOutcome.configurationError
          : FragmentPurchaseOutcome.serviceUnavailable,
      errorKind: error.kind,
      message: error.message,
    );
  }

  FragmentOrder? _safeFind(String orderId) {
    try {
      return _orders.findByOrderId(orderId);
    } catch (error) {
      BotLog.error('fragment order_lookup_failed order=$orderId error=$error');
      return null;
    }
  }
}

String _normalizeUsername(String username) {
  final value = username.trim();
  return value.startsWith('@') ? value.substring(1) : value;
}

String _newOrderId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  final suffix = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0'));
  return 'frag_${DateTime.now().toUtc().microsecondsSinceEpoch}_${suffix.join()}';
}
