import 'package:pozzy_bot/app/labels/format/emoji.dart';
import 'package:pozzy_bot/app/labels/format/money_formatter.dart';
import 'package:pozzy_bot/services/fragment/fragment_pricing_service.dart';

abstract final class PremiumPurchaseText {
  static final menu = '''
${Emoji.premium}Покупка Telegram Premium

Выберите срок подписки:
''';

  static const threeMonthsButtonText = '3 месяца';
  static const sixMonthsButtonText = '6 месяцев';
  static const twelveMonthsButtonText = '12 месяцев';
  static const backButtonText = 'Назад';

  static String selected(FragmentPriceQuote quote) =>
      'Выбрано: <b>${quote.quantityUnits} мес. Premium</b>\n'
      'Стоимость: <b>${MoneyFormatter.fixed(quote.price.toLegacyDouble())}\$</b>';

  static String completed({required int months, required String username}) =>
      '<b>Покупка выполнена</b>\n\n'
      '$months мес. Premium отправлено получателю'
      '$username';
}
