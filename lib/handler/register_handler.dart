import 'dart:async';

import 'package:pozzy_bot/app/labels/button/adminMenu/admin_callback.dart';
import 'package:pozzy_bot/handler/purchase/fragment_purchase_coordinator.dart';
import 'package:pozzy_bot/handler/purchase/recipient/recipient_selection_handler.dart';
import 'package:pozzy_bot/handler/purchase/stars/stars_purchase_handler.dart';
import 'package:pozzy_bot/handler/purchase/ton/ton_purchase_handler.dart';
import 'package:pozzy_bot/handler/referral_inline_query_handler.dart';
import 'package:pozzy_bot/handler/start_handler.dart';
import 'package:pozzy_bot/router/callback_router.dart';
import 'package:televerse/televerse.dart';

abstract final class RegisterHandler {
  static void register(
    Bot<Context> bot, {
    required StartHandler start,
    required CallbackRouter callbackRouter,
    required ReferralInlineQueryHandler referralInlineQuery,
    required StarsPurchaseHandler starsPurchase,
    required TonPurchaseHandler tonPurchase,
    required RecipientSelectionHandler recipientSelection,
    required FragmentPurchaseCoordinator purchaseCoordinator,
  }) {
    bot.use(_instantCallbackAnswerMiddleware);
    bot.command('start', (ctx) async {
      purchaseCoordinator.cancelForNavigation(ctx);
      await start.onStart(ctx);
    });
    bot.onCallbackQuery(callbackRouter.route);
    bot.onInlineQuery(referralInlineQuery.onInlineQuery);
    bot.onMessage((ctx) async {
      if (purchaseCoordinator.onAnyMessage(ctx)) return;
      if (await starsPurchase.onAnyMessage(ctx)) return;
      if (await tonPurchase.onAnyMessage(ctx)) return;
      await recipientSelection.onAnyMessage(ctx);
    });
  }

  static Future<void> _instantCallbackAnswerMiddleware(
    Context ctx,
    NextFunction next,
  ) async {
    final query = ctx.callbackQuery;
    if (query != null) {
      final data = query.data?.trim();
      if (data == null || !AdminCallback.isAdminCallback(data)) {
        unawaited(ctx.answerCallbackQuery().catchError((_) => false));
      }
    }
    await next();
  }
}
