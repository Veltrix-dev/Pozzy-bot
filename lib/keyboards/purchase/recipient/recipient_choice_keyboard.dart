import 'package:pozzy_bot/app/labels/button/purchase/recipient/recipient_selection_callbacks.dart';
import 'package:pozzy_bot/app/labels/id/premium_emoji_ids.dart';
import 'package:pozzy_bot/app/labels/message/purchase/recipient/recipient_selection_text.dart';
import 'package:televerse/telegram.dart';

class RecipientChoiceKeyboard {
  InlineKeyboardMarkup get markup => InlineKeyboardMarkup(
    inlineKeyboard: [
      [
        InlineKeyboardButton(
          text: RecipientSelectionText.toSelfButtonText,
          callbackData: RecipientSelectionCallbacks.toSelf,
          iconCustomEmojiId: PremiumEmojiIds.profile,
        ),
      ],
      [
        InlineKeyboardButton(
          text: RecipientSelectionText.toOtherButtonText,
          callbackData: RecipientSelectionCallbacks.toOther,
          iconCustomEmojiId: PremiumEmojiIds.profile3,
        ),
      ],
    ],
  );
}
