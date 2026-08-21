import 'package:pozzy_bot/app/labels/button/mainMenu/callback.dart';
import 'package:pozzy_bot/app/labels/button/purchase/premium/premium_purchase_callbacks.dart';
import 'package:pozzy_bot/app/labels/id/premium_emoji_ids.dart';
import 'package:pozzy_bot/app/labels/message/purchase/premium/premium_purchase_text.dart';
import 'package:televerse/telegram.dart';

class PremiumPurchaseKeyboard {
  PremiumPurchaseKeyboard({
    required this.durationPricesRub,
    required this.generation,
  });

  final Map<int, int> durationPricesRub;
  final String generation;

  InlineKeyboardMarkup get markup => InlineKeyboardMarkup(
    inlineKeyboard: [
      [_durationButton(3)],
      [_durationButton(6)],
      [_durationButton(12)],
      [
        InlineKeyboardButton(
          text: PremiumPurchaseText.backButtonText,
          callbackData: Callback.mainMenu,
          iconCustomEmojiId: PremiumEmojiIds.back,
        ),
      ],
    ],
  );

  InlineKeyboardButton _durationButton(int months) {
    final priceRub = durationPricesRub[months];
    if (priceRub == null) {
      throw StateError('Missing RUB price for $months months Premium');
    }
    return _button(
      PremiumPurchaseText.durationButtonText(
        months: months,
        priceRub: priceRub,
      ),
      PremiumPurchaseCallbacks.durationCallback(
        generation: generation,
        months: months,
      ),
    );
  }

  InlineKeyboardButton _button(String text, String callbackData) =>
      InlineKeyboardButton(
        text: text,
        callbackData: callbackData,
        iconCustomEmojiId: PremiumEmojiIds.premium,
      );
}
