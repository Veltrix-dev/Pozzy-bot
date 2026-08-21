import 'package:pozzy_bot/app/labels/button/adminMenu/admin_button_labels.dart';
import 'package:pozzy_bot/app/labels/button/adminMenu/admin_callback.dart';
import 'package:pozzy_bot/app/labels/id/premium_emoji_ids.dart';
import 'package:televerse/telegram.dart';

abstract final class AdminMenuKeyboard {
  static InlineKeyboardMarkup get main => const InlineKeyboardMarkup(
    inlineKeyboard: [
      [
        InlineKeyboardButton(
          text: AdminButtonLabels.statistics,
          callbackData: AdminCallback.statistics,
          iconCustomEmojiId: PremiumEmojiIds.statistics,
        ),
      ],
      [
        InlineKeyboardButton(
          text: AdminButtonLabels.userInfo,
          callbackData: AdminCallback.userInfo,
          iconCustomEmojiId: PremiumEmojiIds.profile,
        ),
      ],
      [
        InlineKeyboardButton(
          text: AdminButtonLabels.topUpBalance,
          callbackData: AdminCallback.topUpUserBalance,
          iconCustomEmojiId: PremiumEmojiIds.balance,
        ),
      ],
      [
        InlineKeyboardButton(
          text: AdminButtonLabels.broadcast,
          callbackData: AdminCallback.broadcast,
          iconCustomEmojiId: PremiumEmojiIds.send,
        ),
        InlineKeyboardButton(
          text: AdminButtonLabels.administrators,
          callbackData: AdminCallback.administrators,
          iconCustomEmojiId: PremiumEmojiIds.profile2,
        ),
      ],
      [
        InlineKeyboardButton(
          text: AdminButtonLabels.back,
          callbackData: AdminCallback.close,
          iconCustomEmojiId: PremiumEmojiIds.back,
        ),
      ],
    ],
  );

  static InlineKeyboardMarkup confirmation({required String confirmCallback}) =>
      InlineKeyboardMarkup(
        inlineKeyboard: [
          [
            InlineKeyboardButton(
              text: AdminButtonLabels.confirm,
              callbackData: confirmCallback,
              iconCustomEmojiId: PremiumEmojiIds.checkMark,
            ),
            const InlineKeyboardButton(
              text: AdminButtonLabels.cancel,
              callbackData: AdminCallback.cancel,
              iconCustomEmojiId: PremiumEmojiIds.back,
            ),
          ],
        ],
      );

  static InlineKeyboardMarkup get back => const InlineKeyboardMarkup(
    inlineKeyboard: [
      [
        InlineKeyboardButton(
          text: AdminButtonLabels.back,
          callbackData: AdminCallback.openPanel,
          iconCustomEmojiId: PremiumEmojiIds.back,
        ),
      ],
    ],
  );
}
