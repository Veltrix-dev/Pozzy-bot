import 'package:pozzy_bot/app/labels/button/profileMenu/profile_buttons.dart';
import 'package:pozzy_bot/app/labels/button/profileMenu/profile_callbacks.dart';
import 'package:pozzy_bot/app/labels/id/premium_emoji_ids.dart';
import 'package:televerse/telegram.dart';

class ProfileMenuKeyboard {
  InlineKeyboardMarkup get markup => InlineKeyboardMarkup(
    inlineKeyboard: [
      [
        InlineKeyboardButton(
          text: ProfileButtons.referrals,
          callbackData: ProfileCallbacks.referrals,
          iconCustomEmojiId: PremiumEmojiIds.profile2,
        ),
      ],
      [
        InlineKeyboardButton(
          text: ProfileButtons.statistics,
          callbackData: ProfileCallbacks.statistics,
          iconCustomEmojiId: PremiumEmojiIds.statistics,
        ),
      ],
    ],
  );
}
