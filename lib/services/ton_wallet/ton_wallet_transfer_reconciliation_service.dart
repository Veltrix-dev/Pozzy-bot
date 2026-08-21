import 'dart:async';

import 'package:pozzy_bot/app/labels/message/purchase/ton/ton_purchase_text.dart';
import 'package:pozzy_bot/config/config.dart';
import 'package:pozzy_bot/database/models/ton_wallet_transfer.dart';
import 'package:pozzy_bot/database/repositories/ton_wallet_transfer_repository.dart';
import 'package:pozzy_bot/handler/reply_handler.dart';
import 'package:pozzy_bot/services/ton_wallet/ton_wallet_transfer_service.dart';
import 'package:pozzy_bot/utils/bot_log.dart';
import 'package:televerse/televerse.dart';

class TonWalletTransferReconciliationService {
  TonWalletTransferReconciliationService({
    required TonWalletTransferRepository transfers,
    required TonWalletTransferService service,
    required ReplyHandler reply,
  }) : _transfers = transfers,
       _service = service,
       _reply = reply;

  final TonWalletTransferRepository _transfers;
  final TonWalletTransferService _service;
  final ReplyHandler _reply;

  Timer? _timer;
  bool _running = false;

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(
      Duration(seconds: Config.tonWalletReconciliationIntervalSeconds),
      (_) => unawaited(runCycle()),
    );
    unawaited(runCycle());
  }

  Future<void> runCycle() async {
    if (_running) return;
    _running = true;
    try {
      final pending = _transfers.findRecoverable(
        minimumAge: Duration(
          seconds: Config.tonWalletReconciliationMinAgeSeconds,
        ),
      );
      for (final transfer in pending) {
        final result = await _service.reconcile(transfer);
        if (result.outcome == TonWalletTransferOutcome.completed) {
          await _notifyCompleted(result.transfer!);
        } else if (result.outcome == TonWalletTransferOutcome.failed) {
          await _notifyFailed(result.transfer!);
        }
      }
      final staleCreated = _transfers.findStaleCreated(
        minimumAge: Duration(seconds: Config.tonApiTimeoutSeconds * 6),
      );
      for (final transfer in staleCreated) {
        _transfers.markFailed(
          operationId: transfer.operationId,
          errorKind: 'abandoned_before_prepare',
          errorDetail: 'Operation stopped before a signed BOC was persisted',
        );
      }
    } catch (error, stackTrace) {
      BotLog.error('ton reconciliation_failed error=$error\n$stackTrace');
    } finally {
      _running = false;
    }
  }

  Future<void> _notifyCompleted(TonWalletTransfer transfer) async {
    try {
      await _reply.sendText(
        ChatID(transfer.buyerTelegramId),
        TonPurchaseText.walletTransferCompleted(transfer),
      );
    } catch (error) {
      BotLog.error(
        'ton reconciliation_notify_failed operation=${transfer.operationId} '
        'buyer=${transfer.buyerTelegramId} error=$error',
      );
    }
  }

  Future<void> _notifyFailed(TonWalletTransfer transfer) async {
    try {
      await _reply.sendText(
        ChatID(transfer.buyerTelegramId),
        TonPurchaseText.transferFailed,
      );
    } catch (error) {
      BotLog.error(
        'ton reconciliation_notify_failed operation=${transfer.operationId} '
        'buyer=${transfer.buyerTelegramId} error=$error',
      );
    }
  }

  void close() {
    _timer?.cancel();
    _timer = null;
  }
}
