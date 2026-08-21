import 'package:pozzy_bot/app/labels/message/purchase/common/fragment_payment_text.dart';
import 'package:pozzy_bot/app/labels/message/purchase/recipient/recipient_selection_text.dart';
import 'package:pozzy_bot/handler/reply_handler.dart';
import 'package:pozzy_bot/services/fragment/fragment_purchase_flow_service.dart';
import 'package:televerse/telegram.dart';
import 'package:televerse/televerse.dart';

class FragmentPurchaseCoordinator {
  FragmentPurchaseCoordinator({
    required ReplyHandler reply,
    required FragmentPurchaseFlowService flows,
    DateTime Function()? clock,
  }) : _reply = reply,
       _flows = flows,
       _clock = clock ?? DateTime.now;

  final ReplyHandler _reply;
  final FragmentPurchaseFlowService _flows;
  final DateTime Function() _clock;

  bool isBusy(int buyerTelegramId) {
    final step = _flows.find(buyerTelegramId)?.step;
    return step == FragmentPurchaseFlowStep.resolvingRecipient ||
        step == FragmentPurchaseFlowStep.purchasing;
  }

  bool onAnyMessage(Context ctx) {
    final from = ctx.from;
    if (from == null ||
        _flows.find(from.id)?.step != FragmentPurchaseFlowStep.purchasing) {
      return false;
    }
    return true;
  }

  Future<void> continueToPayment(
    Context ctx, {
    required String username,
    required String idempotencyKey,
  }) async {
    final from = ctx.from;
    if (from == null) return;
    final begin = _flows.beginPurchase(
      from.id,
      idempotencyKey: idempotencyKey,
      now: _clock(),
    );
    switch (begin.outcome) {
      case FragmentPurchaseBeginOutcome.invalidState:
        return;
      case FragmentPurchaseBeginOutcome.quoteExpired:
        _flows.cancel(from.id);
        await _reply.sendText(
          ctx.id,
          FragmentPaymentText.quoteExpired,
          replyMarkup: const ReplyKeyboardRemove(),
        );
        return;
      case FragmentPurchaseBeginOutcome.started:
        break;
    }
    _flows.cancel(from.id);

    await _reply.sendProcessingStatus(
      ctx.id,
      RecipientSelectionText.confirmed(username),
    );
    await _reply.sendText(
      ctx.id,
      FragmentPaymentText.inDevelopment,
      replyMarkup: const ReplyKeyboardRemove(),
    );
  }

  void cancel(Context ctx) {
    final from = ctx.from;
    if (from == null) return;
    final draft = _flows.find(from.id);
    if (draft == null) return;
    if (draft.step == FragmentPurchaseFlowStep.purchasing) return;
    _flows.cancel(from.id);
  }

  void cancelForNavigation(Context ctx) {
    final from = ctx.from;
    if (from == null) return;
    final draft = _flows.find(from.id);
    if (draft == null || draft.step == FragmentPurchaseFlowStep.purchasing) {
      return;
    }
    _flows.cancel(from.id);
  }
}
