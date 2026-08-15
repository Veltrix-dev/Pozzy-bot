import 'package:pozzy_bot/app/labels/button/purchase/recipient/recipient_selection_callbacks.dart';
import 'package:pozzy_bot/app/labels/id/premium_emoji_ids.dart';
import 'package:pozzy_bot/app/labels/message/purchase/recipient/recipient_selection_text.dart';
import 'package:televerse/telegram.dart';

class RecipientBackKeyboard {
  InlineKeyboardMarkup get markup => const InlineKeyboardMarkup(
    inlineKeyboard: [
      [
        InlineKeyboardButton(
          text: RecipientSelectionText.backButtonText,
          callbackData: RecipientSelectionCallbacks.back,
          iconCustomEmojiId: PremiumEmojiIds.back,
        ),
      ],
    ],
  );
}
