import 'dart:async';

import 'package:pozzy_bot/app/labels/button/adminMenu/admin_callback.dart';
import 'package:pozzy_bot/handler/main_menu_handler.dart';
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
    }) {
     bot.use(_instantCallbackAnswerMiddleware);
     bot.command('start', start.onStart);
     bot.onCallbackQuery(callbackRouter.route);
     bot.onInlineQuery(referralInlineQuery.onInlineQuery);
    }

   static Future<void> _instantCallbackAnswerMiddleware(
    Context ctx,
    NextFunction next,
  ) async {
    final query = ctx.callbackQuery;
    if(query != null) {
      final data = query.data?.trim();
      if(data == null || !AdminCallback.isAdminCallback(data)) {
        unawaited(
          ctx.answerCallbackQuery().catchError((_) => false),
        );
      }
    }
    await next();
  }

}
