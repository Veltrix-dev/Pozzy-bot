import 'package:pozzy_bot/app/labels/message/purchase/recipient/recipient_selection_text.dart';
import 'package:pozzy_bot/handler/purchase/fragment_purchase_coordinator.dart';
import 'package:pozzy_bot/handler/reply_handler.dart';
import 'package:pozzy_bot/keyboards/purchase/recipient/recipient_back_keyboard.dart';
import 'package:pozzy_bot/keyboards/purchase/recipient/recipient_choice_keyboard.dart';
import 'package:pozzy_bot/services/fragment/fragment_purchase_flow_service.dart';
import 'package:pozzy_bot/services/fragment/fragment_recipient_resolver.dart';
import 'package:pozzy_bot/utils/telegram_username.dart';
import 'package:televerse/televerse.dart';

class RecipientSelectionHandler {
  RecipientSelectionHandler({
    required ReplyHandler reply,
    required FragmentPurchaseFlowService flows,
    required FragmentRecipientResolver recipients,
    required FragmentPurchaseCoordinator coordinator,
  }) : _reply = reply,
       _flows = flows,
       _recipients = recipients,
       _coordinator = coordinator;

  final ReplyHandler _reply;
  final FragmentPurchaseFlowService _flows;
  final FragmentRecipientResolver _recipients;
  final FragmentPurchaseCoordinator _coordinator;

  Future<void> showChoice(Context ctx) async {
    await _reply.sendText(
      ctx.id,
      RecipientSelectionText.chooseRecipient,
      replyMarkup: RecipientChoiceKeyboard().markup,
    );
  }

  Future<void> onToSelf(Context ctx) async {
    final from = ctx.from;
    if (from == null) return;
    final username = TelegramUsername.normalize(from.username);
    if (username == null) {
      await _reply.sendText(ctx.id, RecipientSelectionText.usernameMissing);
      return;
    }
    await _resolve(
      ctx,
      rawUsername: username,
      expectedStep: FragmentPurchaseFlowStep.awaitingRecipientChoice,
    );
  }

  Future<void> onToOther(Context ctx) async {
    final from = ctx.from;
    if (from == null || !_flows.awaitOtherRecipient(from.id)) return;
    await _reply.sendText(
      ctx.id,
      RecipientSelectionText.askUsername,
      replyMarkup: RecipientBackKeyboard().markup,
    );
  }

  Future<void> onBack(Context ctx) async {
    final from = ctx.from;
    if (from == null || !_flows.returnToRecipientChoice(from.id)) return;
    await showChoice(ctx);
  }

  Future<bool> onAnyMessage(Context ctx) async {
    final from = ctx.from;
    if (from == null) return false;
    final draft = _flows.find(from.id);
    if (draft == null) return false;
    if (draft.step == FragmentPurchaseFlowStep.resolvingRecipient) {
      return true;
    }
    if (draft.step == FragmentPurchaseFlowStep.awaitingRecipientChoice) {
      await showChoice(ctx);
      return true;
    }
    if (draft.step != FragmentPurchaseFlowStep.awaitingOtherRecipient) {
      return false;
    }

    final text = ctx.message?.text?.trim();
    if (text == null || text.isEmpty) {
      await _reply.sendText(ctx.id, RecipientSelectionText.wrongMessageType);
      return true;
    }
    if (TelegramUsername.normalize(text) == null) {
      await _reply.sendText(ctx.id, RecipientSelectionText.invalidUsername);
      return true;
    }
    await _resolve(
      ctx,
      rawUsername: text,
      expectedStep: FragmentPurchaseFlowStep.awaitingOtherRecipient,
    );
    return true;
  }

  Future<void> _resolve(
    Context ctx, {
    required String rawUsername,
    required FragmentPurchaseFlowStep expectedStep,
  }) async {
    final from = ctx.from;
    if (from == null) return;
    final draft = _flows.beginRecipientResolution(
      from.id,
      expectedStep: expectedStep,
    );
    if (draft == null) return;

    await _reply.sendProcessingStatus(ctx.id, RecipientSelectionText.checking);
    final resolution = await _recipients.resolve(rawUsername);
    if (resolution.outcome != FragmentRecipientResolutionOutcome.resolved) {
      final restored = _flows.restoreAfterFailure(
        from.id,
        idempotencyKey: draft.idempotencyKey,
      );
      if (!restored) return;
      await _reply.sendText(ctx.id, _failureText(resolution.outcome));
      return;
    }

    await _coordinator.continueToPayment(
      ctx,
      username: resolution.username!,
      idempotencyKey: draft.idempotencyKey,
    );
  }

  String _failureText(FragmentRecipientResolutionOutcome outcome) {
    return switch (outcome) {
      FragmentRecipientResolutionOutcome.invalidUsername =>
        RecipientSelectionText.invalidUsername,
      FragmentRecipientResolutionOutcome.recipientNotFound =>
        RecipientSelectionText.recipientNotFound,
      FragmentRecipientResolutionOutcome.serviceUnavailable ||
      FragmentRecipientResolutionOutcome.unexpectedResponse =>
        RecipientSelectionText.serviceUnavailable,
      FragmentRecipientResolutionOutcome.resolved =>
        RecipientSelectionText.serviceUnavailable,
    };
  }
}
