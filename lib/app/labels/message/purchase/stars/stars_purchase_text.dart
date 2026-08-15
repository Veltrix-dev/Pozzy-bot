import 'package:pozzy_bot/app/labels/format/emoji.dart';
import 'package:pozzy_bot/services/fragment/fragment_pricing_service.dart';

abstract final class StarsPurchaseText {
  static final menu =
      '''
${Emoji.stars}Покупка Telegram Stars:

Выберите готовый пакет или укажите другое количество:
''';

  static final enterAmount = '${Emoji.stars}Введите количество Stars минимум 50:';
  static final invalidAmount =
      'Некорректное количество Stars${Emoji.exclamationMark}\nВведите целое число от 50 до 1 000 000:';

  static const customAmountButtonText = 'Другое количество';
  static const backButtonText = 'Назад';

  static String packageButtonText({
    required int amount,
    required int priceRub,
  }) => '$amount звёзд - $priceRub₽';

  static String selected({
    required FragmentPriceQuote quote,
    required int priceRub,
  }) =>
      'Выбрано: <b>${quote.quantityUnits} Stars</b>\n'
      'Стоимость: <b>$priceRub₽</b>';

  static String completed({required int amount, required String username}) =>
      'Покупка выполнена${Emoji.checkMark}\n $amount Stars отправлено получателю @$username.';
}
