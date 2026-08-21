import 'package:pozzy_bot/app/labels/button/mainMenu/callback.dart';
import 'package:pozzy_bot/app/labels/button/purchase/ton/ton_purchase_callbacks.dart';
import 'package:pozzy_bot/app/labels/id/premium_emoji_ids.dart';
import 'package:pozzy_bot/app/labels/message/purchase/ton/ton_purchase_text.dart';
import 'package:televerse/telegram.dart';

class TonAmountKeyboard {
  InlineKeyboardMarkup get markup => InlineKeyboardMarkup(
    inlineKeyboard: [
      [
        InlineKeyboardButton(
          text: TonPurchaseText.telegram,
          callbackData: TonPurchaseCallbacks.telegramAccount,
          iconCustomEmojiId: PremiumEmojiIds.telegram2,
        ),
      ],
      [
        InlineKeyboardButton(
          text: TonPurchaseText.wallet,
          callbackData: TonPurchaseCallbacks.wallet,
          iconCustomEmojiId: PremiumEmojiIds.ton,
        ),
      ],
      [
        InlineKeyboardButton(
          text: TonPurchaseText.backButtonText,
          callbackData: Callback.mainMenu,
          iconCustomEmojiId: PremiumEmojiIds.back,
        ),
      ],
    ],
  );

  InlineKeyboardMarkup get amountMarkup => InlineKeyboardMarkup(
    inlineKeyboard: [
      [
        InlineKeyboardButton(
          text: TonPurchaseText.backButtonText,
          callbackData: Callback.buyTon,
          iconCustomEmojiId: PremiumEmojiIds.back,
        ),
      ],
    ],
  );
}
