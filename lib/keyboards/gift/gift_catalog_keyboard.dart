import 'package:pozzy_bot/app/labels/id/premium_emoji_ids.dart';
import 'package:pozzy_bot/app/labels/button/mainMenu/callback.dart';
import 'package:pozzy_bot/keyboards/gift/gift_callbacks.dart';
import 'package:televerse/telegram.dart';

class GiftCatalogKeyboard {
  InlineKeyboardMarkup get markup => InlineKeyboardMarkup(
    inlineKeyboard: [
      _button(GiftCallbacks.gift1, PremiumEmojiIds.bear1),
      _button(GiftCallbacks.gift2, PremiumEmojiIds.bear2),
      _button(GiftCallbacks.gift3, PremiumEmojiIds.bear3),
      _button(GiftCallbacks.gift4, PremiumEmojiIds.bear4),
      _button(GiftCallbacks.gift5, PremiumEmojiIds.bear5),
      _button(GiftCallbacks.gift6, PremiumEmojiIds.bear6),
      _button(GiftCallbacks.gift7, PremiumEmojiIds.bear7),
      _button(GiftCallbacks.gift8, PremiumEmojiIds.bear8),
      [
        InlineKeyboardButton(
          text: 'Назад',
          callbackData: Callback.mainMenu,
          iconCustomEmojiId: PremiumEmojiIds.back,
          style: StyleType.success,
        ),
      ],
    ],
  );

  List<InlineKeyboardButton> _button(String callback, String emojiId) => [
    InlineKeyboardButton(
      text: ' ',
      callbackData: callback,
      iconCustomEmojiId: emojiId,
      style: StyleType.primary,
    ),
  ];
}
