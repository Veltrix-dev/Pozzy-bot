import 'package:pozzy_bot/app/labels/button/profileMenu/profile_callbacks.dart';
import 'package:pozzy_bot/app/labels/id/premium_emoji_ids.dart';
import 'package:pozzy_bot/app/labels/message/profileMenu/referral_text.dart';
import 'package:pozzy_bot/services/referral/referral_service.dart';
import 'package:televerse/telegram.dart';

class ReferralKeyboard {
  ReferralKeyboard({
    required this.referralLink,
    required this.referralCode,
  });

  final String referralLink;
  final String referralCode;

  InlineKeyboardMarkup get markup => InlineKeyboardMarkup(
    inlineKeyboard: [
      [
        InlineKeyboardButton(
          text: ReferralText.copyLinkButton,
          copyText: CopyTextButton(text: referralLink),
          iconCustomEmojiId: PremiumEmojiIds.link
        ),
        InlineKeyboardButton(
          text: ReferralText.shareButton,
          iconCustomEmojiId: PremiumEmojiIds.send,
          switchInlineQueryChosenChat: SwitchInlineQueryChosenChat(
            query: '${ReferralService.startPayloadPrefix}$referralCode',
            allowUserChats: true,
            allowBotChats: true,
            allowGroupChats: true,
          ),
        ),
      ],
      [
        InlineKeyboardButton(
          text: ReferralText.referralsListButton,
          callbackData: ProfileCallbacks.referralsList,
          iconCustomEmojiId: PremiumEmojiIds.profile2,
        ),
      ],
    ],
  );

}

class ReferralShareLinkKeyboard {
  ReferralShareLinkKeyboard(this.referralLink);

  final String referralLink;

  InlineKeyboardMarkup get markup => InlineKeyboardMarkup(
    inlineKeyboard: [
      [
        InlineKeyboardButton(
          text: ReferralText.openReferralLinkButton,
          url: referralLink,
        ),
      ],
    ],
  );
}
