import 'package:pozzy_bot/app/labels/format/emoji.dart';
import 'package:pozzy_bot/app/labels/format/html_format.dart';
import 'package:pozzy_bot/app/labels/format/money_formatter.dart';
import 'package:pozzy_bot/app/labels/id/premium_emoji_ids.dart';
import 'package:pozzy_bot/services/gift/gift_catalog.dart';

abstract final class GiftMenuText {
  static String build() {
    final lines = GiftCatalog.products.map(
      (product) =>
          '${_emojiFor(product.kind)} — ${MoneyFormatter.fixed(product.priceUsd)}\$',
    );

    return '''
${Emoji.deletedGifts} Выберите удалённый подарок:

<blockquote>${lines.join('\n')}</blockquote>

${Emoji.menu}Выбор подарка доступен через меню ниже:
'''
        .trim();
  }

  static String _emojiFor(GiftKind kind) {
    final id = switch (kind) {
      GiftKind.gift1 => PremiumEmojiIds.bear1,
      GiftKind.gift2 => PremiumEmojiIds.bear2,
      GiftKind.gift3 => PremiumEmojiIds.bear3,
      GiftKind.gift4 => PremiumEmojiIds.bear4,
      GiftKind.gift5 => PremiumEmojiIds.bear5,
      GiftKind.gift6 => PremiumEmojiIds.bear6,
      GiftKind.gift7 => PremiumEmojiIds.bear7,
      GiftKind.gift8 => PremiumEmojiIds.bear8,
    };
    return HtmlFormat.emoji(id, '🧸');
  }
}
