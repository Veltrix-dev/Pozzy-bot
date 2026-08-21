import 'dart:convert';
import 'dart:math';

import 'package:pozzy_bot/database/models/ton_amount.dart';
import 'package:pozzy_bot/database/models/ton_wallet_transfer.dart';
import 'package:pozzy_bot/database/models/usd_amount.dart';
import 'package:pozzy_bot/database/repositories/ton_wallet_transfer_repository.dart';
import 'package:pozzy_bot/services/referral/referral_service.dart';
import 'package:pozzy_bot/services/ton_api/ton_api_exception.dart';
import 'package:pozzy_bot/services/ton_wallet/ton_wallet_gateway.dart';
import 'package:pozzy_bot/utils/bot_log.dart';
import 'package:sqlite3/sqlite3.dart';

enum TonWalletTransferOutcome {
  completed,
  alreadyCompleted,
  pendingConfirmation,
  transferInProgress,
  invalidInput,
  invalidAddress,
  hotWalletInsufficientBalance,
  configurationError,
  unauthorized,
  rateLimited,
  serviceUnavailable,
  idempotencyConflict,
  databaseError,
  failed,
}

class TonWalletTransferResult {
  const TonWalletTransferResult({required this.outcome, this.transfer});

  final TonWalletTransferOutcome outcome;
  final TonWalletTransfer? transfer;
}

class TonWalletTransferService {
  TonWalletTransferService({
    required TonWalletTransferRepository transfers,
    required TonWalletGateway wallet,
    ReferralService? referrals,
  }) : _transfers = transfers,
       _wallet = wallet,
       _referrals = referrals;

  final TonWalletTransferRepository _transfers;
  final TonWalletGateway _wallet;
  final ReferralService? _referrals;
  final Random _random = Random.secure();

  String normalizeAddress(String value) => _wallet.normalizeAddress(value);

  Future<TonAmount> getWalletBalance({String? address}) =>
      _wallet.getBalance(address: address);

  Future<TonWalletTransferResult> deliverPaidTon({
    required String idempotencyKey,
    required int buyerTelegramId,
    required String recipientAddress,
    required TonAmount amount,
    required UsdAmount price,
    String? comment,
    String? payloadBase64,
  }) async {
    if (buyerTelegramId <= 0 ||
        amount.isZero ||
        price.isZero ||
        !_isValidIdempotencyKey(idempotencyKey)) {
      return const TonWalletTransferResult(
        outcome: TonWalletTransferOutcome.invalidInput,
      );
    }
    String normalizedAddress;
    try {
      normalizedAddress = _wallet.normalizeAddress(recipientAddress);
    } on TonApiException {
      return const TonWalletTransferResult(
        outcome: TonWalletTransferOutcome.invalidAddress,
      );
    }
    final identity = jsonEncode({
      'buyer': buyerTelegramId,
      'recipient': normalizedAddress,
      'amount_nano': amount.nano,
      'price_usd_micros': price.micros,
      'comment': comment,
      'payload': payloadBase64,
    });
    TonTransferCreateResult created;
    try {
      created = _transfers.create(
        operationId: _newOperationId(),
        idempotencyKey: idempotencyKey.trim(),
        requestIdentity: identity,
        buyerTelegramId: buyerTelegramId,
        recipientAddress: normalizedAddress,
        amount: amount,
        price: price,
      );
    } on SqliteException catch (error, stackTrace) {
      BotLog.error(
        'ton transfer_create_db_failed buyer=$buyerTelegramId '
        'error=$error\n$stackTrace',
      );
      return const TonWalletTransferResult(
        outcome: TonWalletTransferOutcome.databaseError,
      );
    }
    switch (created.outcome) {
      case TonTransferCreateOutcome.idempotencyConflict:
        return TonWalletTransferResult(
          outcome: TonWalletTransferOutcome.idempotencyConflict,
          transfer: created.transfer,
        );
      case TonTransferCreateOutcome.existing:
        return _resultForExisting(created.transfer!);
      case TonTransferCreateOutcome.created:
        break;
    }
    return _execute(
      created.transfer!,
      comment: comment,
      payloadBase64: payloadBase64,
    );
  }

  Future<TonWalletTransferResult> reconcile(TonWalletTransfer transfer) async {
    final messageHash = transfer.messageHash;
    final signedBoc = transfer.signedBoc;
    if (messageHash == null || signedBoc == null) {
      return TonWalletTransferResult(
        outcome: TonWalletTransferOutcome.failed,
        transfer: transfer,
      );
    }
    try {
      var confirmation = await _wallet.findConfirmation(messageHash);
      if (confirmation.status == TonWalletSendStatus.pending) {
        try {
          await _wallet.rebroadcast(signedBoc);
        } on TonApiException catch (error) {
          _transfers.markPending(
            operationId: transfer.operationId,
            errorKind: error.kind.name,
            errorDetail: error.message,
          );
          return _pendingResult(transfer.operationId);
        }
        confirmation = await _wallet.findConfirmation(messageHash);
      }
      return _applyConfirmation(transfer, confirmation);
    } on TonApiException catch (error) {
      _transfers.markPending(
        operationId: transfer.operationId,
        errorKind: error.kind.name,
        errorDetail: error.message,
      );
      return _pendingResult(transfer.operationId);
    } on SqliteException catch (error, stackTrace) {
      BotLog.error(
        'ton reconciliation_db_failed operation=${transfer.operationId} '
        'error=$error\n$stackTrace',
      );
      return TonWalletTransferResult(
        outcome: TonWalletTransferOutcome.databaseError,
        transfer: _transfers.findByOperationId(transfer.operationId),
      );
    }
  }

  Future<TonWalletTransferResult> _execute(
    TonWalletTransfer transfer, {
    String? comment,
    String? payloadBase64,
  }) async {
    BotLog.event(
      'ton transfer_started operation=${transfer.operationId} '
      'buyer=${transfer.buyerTelegramId} amount_nano=${transfer.amount.nano} '
      'recipient=${_maskAddress(transfer.recipientAddress)}',
    );
    try {
      final result = await _wallet.sendTon(
        operationId: transfer.operationId,
        recipientAddress: transfer.recipientAddress,
        amount: transfer.amount,
        comment: comment,
        payloadBase64: payloadBase64,
        onPrepared: (prepared) async {
          final outcome = _transfers.markPrepared(
            operationId: transfer.operationId,
            signedBoc: prepared.signedBoc,
            messageHash: prepared.messageHash,
          );
          switch (outcome) {
            case TonTransferPrepareOutcome.prepared:
              return;
            case TonTransferPrepareOutcome.invalidStatus:
              throw const _PrepareTransferException();
          }
        },
      );
      final latest = _transfers.findByOperationId(transfer.operationId)!;
      return _applyConfirmation(
        latest,
        TonWalletConfirmation(status: result.status, txHash: result.txHash),
      );
    } on _PrepareTransferException {
      _transfers.markFailed(
        operationId: transfer.operationId,
        errorKind: 'invalid_operation_state',
        errorDetail: 'Transfer was not broadcast',
      );
      return TonWalletTransferResult(
        outcome: TonWalletTransferOutcome.transferInProgress,
        transfer: _transfers.findByOperationId(transfer.operationId),
      );
    } on TonApiException catch (error) {
      final latest = _transfers.findByOperationId(transfer.operationId)!;
      BotLog.error(
        'ton transfer_api_failed operation=${transfer.operationId} '
        'kind=${error.kind.name} status=${error.statusCode ?? 'none'} '
        'uncertain=${error.executionUncertain}',
      );
      if ((latest.status == TonWalletTransferStatus.prepared ||
              latest.status == TonWalletTransferStatus.pending) &&
          error.executionUncertain) {
        _transfers.markPending(
          operationId: transfer.operationId,
          errorKind: error.kind.name,
          errorDetail: error.message,
        );
        return _pendingResult(transfer.operationId);
      }
      return _fail(
        latest,
        errorKind: error.kind.name,
        errorDetail: error.message,
        outcome: _outcomeForApiError(error),
      );
    } on SqliteException catch (error, stackTrace) {
      BotLog.error(
        'ton transfer_db_failed operation=${transfer.operationId} '
        'error=$error\n$stackTrace',
      );
      return TonWalletTransferResult(
        outcome: TonWalletTransferOutcome.databaseError,
        transfer: _transfers.findByOperationId(transfer.operationId),
      );
    } catch (error, stackTrace) {
      BotLog.error(
        'ton transfer_failed operation=${transfer.operationId} '
        'error=$error\n$stackTrace',
      );
      final latest = _transfers.findByOperationId(transfer.operationId)!;
      if (latest.status == TonWalletTransferStatus.prepared ||
          latest.status == TonWalletTransferStatus.pending) {
        _transfers.markPending(
          operationId: transfer.operationId,
          errorKind: 'unknown',
          errorDetail: error.toString(),
        );
        return _pendingResult(transfer.operationId);
      }
      return _fail(
        latest,
        errorKind: 'unknown',
        errorDetail: error.toString(),
        outcome: TonWalletTransferOutcome.failed,
      );
    }
  }

  Future<TonWalletTransferResult> _applyConfirmation(
    TonWalletTransfer transfer,
    TonWalletConfirmation confirmation,
  ) async {
    switch (confirmation.status) {
      case TonWalletSendStatus.pending:
        _transfers.markPending(operationId: transfer.operationId);
        return _pendingResult(transfer.operationId);
      case TonWalletSendStatus.onChainFailed:
        return _fail(
          transfer,
          errorKind: 'on_chain_failed',
          errorDetail: 'TON transaction failed on chain',
          outcome: TonWalletTransferOutcome.failed,
        );
      case TonWalletSendStatus.completed:
        final completion = _transfers.markCompleted(
          operationId: transfer.operationId,
          txHash: confirmation.txHash,
        );
        final latest = _transfers.findByOperationId(transfer.operationId);
        if (latest == null ||
            completion == TonTransferCompleteOutcome.invalidStatus) {
          return TonWalletTransferResult(
            outcome: TonWalletTransferOutcome.databaseError,
            transfer: latest,
          );
        }
        if (completion == TonTransferCompleteOutcome.alreadyCompleted) {
          return TonWalletTransferResult(
            outcome: TonWalletTransferOutcome.alreadyCompleted,
            transfer: latest,
          );
        }
        await _creditReferral(latest);
        BotLog.event(
          'ton transfer_completed operation=${latest.operationId} '
          'message_hash=${latest.messageHash} '
          'tx_hash=${latest.txHash ?? 'not_provided'}',
        );
        return TonWalletTransferResult(
          outcome: TonWalletTransferOutcome.completed,
          transfer: latest,
        );
    }
  }

  TonWalletTransferResult _fail(
    TonWalletTransfer transfer, {
    required String errorKind,
    required String errorDetail,
    required TonWalletTransferOutcome outcome,
  }) {
    _transfers.markFailed(
      operationId: transfer.operationId,
      errorKind: errorKind,
      errorDetail: errorDetail,
    );
    return TonWalletTransferResult(
      outcome: outcome,
      transfer: _transfers.findByOperationId(transfer.operationId),
    );
  }

  TonWalletTransferResult _pendingResult(String operationId) {
    return TonWalletTransferResult(
      outcome: TonWalletTransferOutcome.pendingConfirmation,
      transfer: _transfers.findByOperationId(operationId),
    );
  }

  TonWalletTransferResult _resultForExisting(TonWalletTransfer transfer) {
    final outcome = switch (transfer.status) {
      TonWalletTransferStatus.completed =>
        TonWalletTransferOutcome.alreadyCompleted,
      TonWalletTransferStatus.prepared || TonWalletTransferStatus.pending =>
        TonWalletTransferOutcome.pendingConfirmation,
      TonWalletTransferStatus.created =>
        TonWalletTransferOutcome.transferInProgress,
      TonWalletTransferStatus.failed => TonWalletTransferOutcome.failed,
    };
    return TonWalletTransferResult(outcome: outcome, transfer: transfer);
  }

  TonWalletTransferOutcome _outcomeForApiError(TonApiException error) {
    return switch (error.kind) {
      TonApiErrorKind.configuration =>
        TonWalletTransferOutcome.configurationError,
      TonApiErrorKind.invalidInput => TonWalletTransferOutcome.invalidInput,
      TonApiErrorKind.insufficientBalance =>
        TonWalletTransferOutcome.hotWalletInsufficientBalance,
      TonApiErrorKind.unauthorized => TonWalletTransferOutcome.unauthorized,
      TonApiErrorKind.rateLimit => TonWalletTransferOutcome.rateLimited,
      TonApiErrorKind.timeout ||
      TonApiErrorKind.network ||
      TonApiErrorKind.server ||
      TonApiErrorKind.invalidResponse =>
        TonWalletTransferOutcome.serviceUnavailable,
      TonApiErrorKind.rejected ||
      TonApiErrorKind.unknown => TonWalletTransferOutcome.failed,
    };
  }

  Future<void> _creditReferral(TonWalletTransfer transfer) async {
    try {
      await _referrals?.creditPurchaseCommissionExact(
        referralTelegramId: transfer.buyerTelegramId,
        purchaseId: 'ton_wallet:${transfer.operationId}',
        purchaseAmount: transfer.price,
      );
    } catch (error, stackTrace) {
      BotLog.error(
        'ton referral_failed operation=${transfer.operationId} '
        'error=$error\n$stackTrace',
      );
    }
  }

  bool _isValidIdempotencyKey(String value) =>
      RegExp(r'^[A-Za-z0-9._:-]{1,128}$').hasMatch(value.trim());

  String _newOperationId() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    final suffix = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return 'ton_${DateTime.now().toUtc().microsecondsSinceEpoch}_$suffix';
  }

  String _maskAddress(String address) {
    if (address.length <= 12) return '***';
    return '${address.substring(0, 6)}…${address.substring(address.length - 6)}';
  }
}

class _PrepareTransferException implements Exception {
  const _PrepareTransferException();
}
