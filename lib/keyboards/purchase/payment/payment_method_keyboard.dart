import 'package:pozzy_bot/app/labels/button/purchase/payment/payment_method_button_labels.dart';
import 'package:pozzy_bot/app/labels/button/purchase/payment/payment_method_callbacks.dart';
import 'package:pozzy_bot/app/labels/id/premium_emoji_ids.dart';
import 'package:televerse/telegram.dart';

class PaymentMethodKeyboard {
  InlineKeyboardMarkup get markup => InlineKeyboardMarkup(
    inlineKeyboard: [
      [
        InlineKeyboardButton(
          text: PaymentMethodButtonLabels.ton,
          callbackData: PaymentMethodCallbacks.ton,
          iconCustomEmojiId: PremiumEmojiIds.ton,
        ),
      ],
      [
        InlineKeyboardButton(
          text: PaymentMethodButtonLabels.crypto,
          callbackData: PaymentMethodCallbacks.crypto,
          iconCustomEmojiId: PremiumEmojiIds.balance,
        ),
      ],
    ],
  );
}
