import 'package:pozzy_bot/app/labels/message/purchase/common/fragment_purchase_result_text.dart';
import 'package:pozzy_bot/app/labels/message/purchase/premium/premium_purchase_text.dart';
import 'package:pozzy_bot/handler/purchase/fragment_purchase_coordinator.dart';
import 'package:pozzy_bot/handler/purchase/recipient/recipient_selection_handler.dart';
import 'package:pozzy_bot/handler/reply_handler.dart';
import 'package:pozzy_bot/keyboards/premium/premium_purchase_keyboard.dart';
import 'package:pozzy_bot/services/fragment/fragment_api_exception.dart';
import 'package:pozzy_bot/services/fragment/fragment_pricing_service.dart';
import 'package:pozzy_bot/services/fragment/fragment_purchase_flow_service.dart';
import 'package:pozzy_bot/services/telegram/menu_photo_key.dart';
import 'package:pozzy_bot/services/user_service.dart';
import 'package:pozzy_bot/utils/bot_log.dart';
import 'package:televerse/televerse.dart';

class PremiumPurchaseHandler {
  PremiumPurchaseHandler({
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
    _flows.cancel(from.id);
    await _users.getOrCreate(telegramId: from.id, username: from.username);
    await _reply.sendMenuWithPhoto(
      ctx.id,
      photo: MenuPhotoKey.buyPremium,
      text: PremiumPurchaseText.menu,
      replyMarkup: PremiumPurchaseKeyboard().markup,
    );
  }

  Future<void> onSelectDuration(Context ctx, int months) async {
    final from = ctx.from;
    if (from == null) return;
    if (_coordinator.isBusy(from.id)) return;
    await _users.getOrCreate(telegramId: from.id, username: from.username);
    try {
      final quote = _pricing.quotePremium(months);
      _flows.startAwaitingRecipient(buyerTelegramId: from.id, quote: quote);
      await _reply.sendText(ctx.id, PremiumPurchaseText.selected(quote));
      await _recipientSelection.showChoice(ctx);
    } on FragmentApiException catch (error) {
      _flows.cancel(from.id);
      BotLog.error(
        'fragment pricing_failed buyer=${from.id} type=premium '
        'kind=${error.kind.name} status=${error.statusCode ?? 'none'}',
      );
      await _reply.sendText(
        ctx.id,
        FragmentPurchaseResultText.serviceUnavailable,
      );
    }
  }
}
