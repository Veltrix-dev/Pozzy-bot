import 'package:pozzy_bot/app/labels/message/purchase/common/fragment_purchase_result_text.dart';
import 'package:pozzy_bot/app/labels/message/purchase/ton/ton_purchase_text.dart';
import 'package:pozzy_bot/database/models/fragment_purchase_type.dart';
import 'package:pozzy_bot/database/models/ton_amount.dart';
import 'package:pozzy_bot/handler/purchase/fragment_purchase_coordinator.dart';
import 'package:pozzy_bot/handler/purchase/recipient/recipient_selection_handler.dart';
import 'package:pozzy_bot/handler/reply_handler.dart';
import 'package:pozzy_bot/keyboards/ton/ton_amount_keyboard.dart';
import 'package:pozzy_bot/services/fragment/fragment_api_exception.dart';
import 'package:pozzy_bot/services/fragment/fragment_pricing_service.dart';
import 'package:pozzy_bot/services/fragment/fragment_purchase_flow_service.dart';
import 'package:pozzy_bot/services/telegram/menu_photo_key.dart';
import 'package:pozzy_bot/services/user_service.dart';
import 'package:pozzy_bot/utils/bot_log.dart';
import 'package:televerse/televerse.dart';

class TonPurchaseHandler {
  TonPurchaseHandler({
    required ReplyHandler reply,
    required UserService users,
    required FragmentPricingService pricing,
    required FragmentPurchaseFlowService flows,
    required RecipientSelectionHandler recipientSelection,
    required FragmentPurchaseCoordinator coordinator,
  }) : _reply = reply,
       _users = users,
       _pricing = pricing,
       _flows = flows,
       _recipientSelection = recipientSelection,
       _coordinator = coordinator;

  final ReplyHandler _reply;
  final UserService _users;
  final FragmentPricingService _pricing;
  final FragmentPurchaseFlowService _flows;
  final RecipientSelectionHandler _recipientSelection;
  final FragmentPurchaseCoordinator _coordinator;

  Future<void> onOpen(Context ctx) async {
    final from = ctx.from;
    if (from == null) return;
    if (_coordinator.isBusy(from.id)) return;
    await _users.getOrCreate(telegramId: from.id, username: from.username);
    _flows.startAwaitingAmount(
      buyerTelegramId: from.id,
      purchaseType: FragmentPurchaseType.ton,
    );
    await _reply.sendMenuWithPhoto(
      ctx.id,
      photo: MenuPhotoKey.buyTon,
      text: TonPurchaseText.enterAmount,
      replyMarkup: TonAmountKeyboard().markup,
    );
  }

  Future<bool> onAnyMessage(Context ctx) async {
    final from = ctx.from;
    if (from == null) return false;
    final draft = _flows.find(from.id);
    if (draft == null ||
        draft.step != FragmentPurchaseFlowStep.awaitingAmount ||
        draft.purchaseType != FragmentPurchaseType.ton) {
      return false;
    }

    final text = ctx.message?.text?.trim();
    final amount = text == null ? null : _parseAmount(text);
    if (amount == null || amount.isZero) {
      await _reply.sendText(ctx.id, TonPurchaseText.invalidAmount);
      return true;
    }

    try {
      final quote = _pricing.quoteTon(amount);
      final updated = _flows.applyQuote(buyerTelegramId: from.id, quote: quote);
      if (updated != null) {
        await _reply.sendText(ctx.id, TonPurchaseText.selected(quote));
        await _recipientSelection.showChoice(ctx);
      }
    } on FragmentApiException catch (error) {
      _flows.cancel(from.id);
      BotLog.error(
        'fragment pricing_failed buyer=${from.id} type=ton '
        'kind=${error.kind.name} status=${error.statusCode ?? 'none'}',
      );
      await _reply.sendText(
        ctx.id,
        FragmentPurchaseResultText.serviceUnavailable,
      );
    }
    return true;
  }

  TonAmount? _parseAmount(String raw) {
    try {
      return TonAmount.parse(raw.replaceAll(',', '.'));
    } on FormatException {
      return null;
    }
  }
}
