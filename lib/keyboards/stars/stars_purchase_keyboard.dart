import 'package:pozzy_bot/app/labels/button/mainMenu/callback.dart';
import 'package:pozzy_bot/app/labels/button/purchase/stars/stars_purchase_callbacks.dart';
import 'package:pozzy_bot/app/labels/id/premium_emoji_ids.dart';
import 'package:pozzy_bot/app/labels/message/purchase/stars/stars_purchase_text.dart';
import 'package:televerse/telegram.dart';

class StarsPurchaseKeyboard {
  StarsPurchaseKeyboard({
    required this.packagePricesRub,
    required this.generation,
  });

  final Map<int, int> packagePricesRub;
  final String generation;

  InlineKeyboardMarkup get markup => InlineKeyboardMarkup(
    inlineKeyboard: [
      [_packageButton(50)],
      [_packageButton(100)],
      [_packageButton(150)],
      [_packageButton(250)],
      [_packageButton(500)],
      [_packageButton(1000)],
      [_packageButton(2500)],
      [
        _button(
          StarsPurchaseText.customAmountButtonText,
          StarsPurchaseCallbacks.customAmount,
          iconCustomEmojiId: PremiumEmojiIds.plus,
        ),
      ],
      [
        InlineKeyboardButton(
          text: StarsPurchaseText.backButtonText,
          callbackData: Callback.mainMenu,
          iconCustomEmojiId: PremiumEmojiIds.back,
        ),
      ],
    ],
  );

  InlineKeyboardButton _packageButton(int amount) {
    final priceRub = packagePricesRub[amount];
    if (priceRub == null) {
      throw StateError('Missing RUB price for $amount Stars');
    }
    return _button(
      StarsPurchaseText.packageButtonText(amount: amount, priceRub: priceRub),
      StarsPurchaseCallbacks.packageCallback(
        generation: generation,
        amount: amount,
      ),
    );
  }

  InlineKeyboardButton _button(
    String text,
    String callbackData, {
    String iconCustomEmojiId = PremiumEmojiIds.stars,
  }) => InlineKeyboardButton(
    text: text,
    callbackData: callbackData,
    iconCustomEmojiId: iconCustomEmojiId,
  );
}
