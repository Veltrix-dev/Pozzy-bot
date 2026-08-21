import 'package:pozzy_bot/app/labels/format/emoji.dart';
import 'package:pozzy_bot/services/fragment/fragment_pricing_service.dart';

abstract final class PremiumPurchaseText {
  static final menu =
      '''
${Emoji.premium}Покупка Telegram Premium

Выберите срок подписки:
''';

  static const backButtonText = 'Назад';

  static String durationButtonText({
    required int months,
    required int priceRub,
  }) => '$months ${months == 3 ? 'месяца' : 'месяцев'} - $priceRub₽';

  static String selected({
    required FragmentPriceQuote quote,
    required int priceRub,
  }) =>
      'Выбрано: <b>${quote.quantityUnits} мес. Premium</b>\n'
      'Стоимость: <b>$priceRub₽</b>';

  static String completed({required int months, required String username}) =>
      '<b>Покупка выполнена</b>\n\n'
      '$months мес. Premium отправлено получателю'
      '$username';
}
