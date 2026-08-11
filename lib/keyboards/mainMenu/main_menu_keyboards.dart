import 'package:pozzy_bot/app/labels/button/mainMenu/button_labels.dart';
import 'package:pozzy_bot/app/labels/button/mainMenu/callback.dart';
import 'package:pozzy_bot/app/labels/format/emoji.dart';
import 'package:pozzy_bot/app/labels/id/premium_emoji_ids.dart';
import 'package:televerse/telegram.dart';

class MainMenuKeyboards {
  InlineKeyboardMarkup get markup => InlineKeyboardMarkup(
    inlineKeyboard: [
      [
        InlineKeyboardButton(
          text: ButtonLabels.profile,
          callbackData: Callback.profile,
          iconCustomEmojiId: PremiumEmojiIds.profile,
        ),
      ],
      [
        InlineKeyboardButton(
          text: ButtonLabels.buyStars,
          callbackData: Callback.buyStars,
          iconCustomEmojiId: PremiumEmojiIds.stars,
        ),
        InlineKeyboardButton(
          text: ButtonLabels.buyPremium,
          callbackData: Callback.buyPremium,
          iconCustomEmojiId: PremiumEmojiIds.premium,
        ),
      ],
      [
        InlineKeyboardButton(
          text: ButtonLabels.buyTon,
          callbackData: Callback.buyTon,
          iconCustomEmojiId: PremiumEmojiIds.ton,
        ),
        InlineKeyboardButton(
          text: ButtonLabels.communication,
          callbackData: Callback.chatProject,
          iconCustomEmojiId: PremiumEmojiIds.communication,
        ),
      ],
      [
        InlineKeyboardButton(
          text: ButtonLabels.deletedGifts,
          callbackData: Callback.deletedGifts,
          iconCustomEmojiId: PremiumEmojiIds.remotegifts,
        ),
      ],
      [
        InlineKeyboardButton(
          text: ButtonLabels.news,
          callbackData: Callback.news,
          iconCustomEmojiId: PremiumEmojiIds.news,
        ),
        InlineKeyboardButton(
          text: ButtonLabels.support,
          callbackData: Callback.support,
          iconCustomEmojiId: PremiumEmojiIds.support,
        ),
      ],
    ],
  );
}
