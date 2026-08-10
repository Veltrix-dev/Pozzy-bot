import 'package:pozzy_bot/app/labels/message/profileMenu/referral_text.dart';
import 'package:pozzy_bot/keyboards/profileMenu/referral_keyboard.dart';
import 'package:pozzy_bot/services/referral/referral_service.dart';
import 'package:pozzy_bot/utils/bot_log.dart';
import 'package:televerse/telegram.dart';
import 'package:televerse/televerse.dart';

class ReferralInlineQueryHandler {
  ReferralInlineQueryHandler(this._referrals);

  final ReferralService _referrals;

  Future<void> onInlineQuery(Context ctx) async {
    try {
      final query = ctx.inlineQuery?.query.trim() ?? '';
      final referralCode = ReferralService.parseReferralCodeFromStartPayload(
        query,
      );
      if (referralCode == null) {
        await ctx.answerInlineQuery([]);
        return;
      }

      final user = _referrals.findByReferralCode(referralCode);
      if (user == null) {
        await ctx.answerInlineQuery([]);
        return;
      }

      final link = _referrals.buildReferralLink(user);
      final results = InlineQueryResultBuilder()
        ..article(
          '${ReferralService.startPayloadPrefix}$referralCode',
          ReferralText.shareInlineTitle,
          (content) => content.text(
            ReferralText.shareMessage(link: link),
            linkPreviewOptions: LinkPreviewOptions(isDisabled: true),
          ),
          description: ReferralText.shareInlineDescription(link: link),
          replyMarkup: ReferralShareLinkKeyboard(link).markup,
        );

      await ctx.answerInlineQuery(
        results.build(),
        cacheTime: 0,
        isPersonal: true,
      );
    } catch (error, stackTrace) {
      BotLog.error('referral_inline_query_handler: $error');
      if (BotLog.verbose) {
        BotLog.debug(stackTrace.toString());
      }
      await ctx.answerInlineQuery([]);
    }
  }
}
