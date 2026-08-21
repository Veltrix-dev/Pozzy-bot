import 'package:pozzy_bot/app/labels/format/emoji.dart';

import 'package:pozzy_bot/services/gift/gift_catalog.dart';

abstract final class GiftPurchaseText {
  static String paymentInDevelopment(GiftProduct product) =>
      '''
Стоимость: <b>${product.priceRub.toDecimalString()} ₽</b>

Функция оплаты находится в разработке и будет подключена в будущем.
'''
          .trim();

  static final invalidRecipient =
      '${Emoji.scull}Не удалось определить получателя';
  static final giftSent = 'Подарок успешно отправлен${Emoji.checkMark}';
  static final sendingGift = 'Отправляем подарок...';
  static final userbotUnavailable =
      '${Emoji.scull}Сервис подарков временно недоступен';
  static final giftFailed = 'Не удалось отправить подарок${Emoji.sad}';
}
