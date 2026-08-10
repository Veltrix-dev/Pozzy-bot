import 'package:pozzy_bot/app/labels/message/mainMenu/start_message.dart';
import 'package:pozzy_bot/handler/reply_handler.dart';
import 'package:pozzy_bot/services/referral/referral_service.dart';
import 'package:pozzy_bot/services/user_service.dart';
import 'package:pozzy_bot/utils/bot_log.dart';
import 'package:televerse/televerse.dart';

class StartHandler {
  StartHandler(this._users, this._reply, this._referrals);

  final UserService _users;
  final ReplyHandler _reply;
  final ReferralService _referrals;

  Future<void> onStart(Context ctx) async {
    final from = ctx.from;
    if (from == null) return;

    final user = await _users.getOrCreate(
      telegramId: from.id,
      username: from.username,
    );
    if (user == null) return;

    final payload = ctx.message?.text
        ?.split(RegExp(r'\s+'))
        .skip(1)
        .join(' ')
        .trim();
    if (payload != null && payload.isNotEmpty) {
      await _handleReferralPayload(
        ctx,
        payload,
        referralTelegramId: from.id,
        referralUsername: from.username,
      );
    }

    await showMainMenu(ctx.id);
  }

  Future<void> showMainMenu(ChatID chatId) async {
    await _reply.sendMainMenu(chatId, text: StartMessage.startMessage);
  }

  Future<void> _handleReferralPayload(
    Context ctx,
    String payload, {
    required int referralTelegramId,
    String? referralUsername,
  }) async {
    if (!payload.startsWith(ReferralService.startPayloadPrefix)) return;

    final referralCode = ReferralService.parseReferralCodeFromStartPayload(
      payload,
    );
    if (referralCode == null) return;

    try {
      await _referrals.registerReferral(
        referralTelegramId: referralTelegramId,
        referralUsername: referralUsername,
        referralCode: referralCode,
      );
    } catch (error, stackTrace) {
      BotLog.error('referral registration failed: $error');
      if (BotLog.verbose) {
        BotLog.debug(stackTrace.toString());
      }
    }
  }
}
