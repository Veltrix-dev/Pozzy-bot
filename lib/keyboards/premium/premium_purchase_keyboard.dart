import 'package:pozzy_bot/app/labels/button/mainMenu/callback.dart';
import 'package:pozzy_bot/app/labels/button/purchase/premium/premium_purchase_callbacks.dart';
import 'package:pozzy_bot/app/labels/id/premium_emoji_ids.dart';
import 'package:pozzy_bot/app/labels/message/purchase/premium/premium_purchase_text.dart';
import 'package:televerse/telegram.dart';

class PremiumPurchaseKeyboard {
  InlineKeyboardMarkup get markup => InlineKeyboardMarkup(
    inlineKeyboard: [
      [
        _button(
          PremiumPurchaseText.threeMonthsButtonText,
          PremiumPurchaseCallbacks.threeMonths,
        ),
      ],
      [
        _button(
          PremiumPurchaseText.sixMonthsButtonText,
          PremiumPurchaseCallbacks.sixMonths,
        ),
      ],
      [
        _button(
          PremiumPurchaseText.twelveMonthsButtonText,
          PremiumPurchaseCallbacks.twelveMonths,
        ),
      ],
      [
        InlineKeyboardButton(
          text: PremiumPurchaseText.backButtonText,
          callbackData: Callback.mainMenu,
          iconCustomEmojiId: PremiumEmojiIds.back,
        ),
      ],
    ],
  );

  InlineKeyboardButton _button(String text, String callbackData) =>
      InlineKeyboardButton(
        text: text,
        callbackData: callbackData,
        iconCustomEmojiId: PremiumEmojiIds.premium,
      );
}
