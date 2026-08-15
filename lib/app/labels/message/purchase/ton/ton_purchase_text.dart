import 'package:pozzy_bot/app/labels/format/html_format.dart';
import 'package:pozzy_bot/app/labels/format/money_formatter.dart';
import 'package:pozzy_bot/database/models/ton_amount.dart';
import 'package:pozzy_bot/services/fragment/fragment_pricing_service.dart';

abstract final class TonPurchaseText {
  static const enterAmount =
      'Введите количество TON. Можно использовать точку или запятую.';
  static const invalidAmount =
      'Некорректное количество TON. Введите положительное число.';
  static const backButtonText = 'Назад';

  static String selected(FragmentPriceQuote quote) {
    final amount = TonAmount.fromNano(quote.quantityUnits).toDecimalString();
    return 'Выбрано: <b>$amount TON</b>\n'
        'Стоимость: <b>${MoneyFormatter.fixed(quote.price.toLegacyDouble())}\$</b>';
  }

  static String completed({
    required TonAmount amount,
    required String username,
  }) =>
      '<b>Покупка выполнена</b>\n\n'
      '${amount.toDecimalString()} TON отправлено получателю '
      '${HtmlFormat.code('@$username')}.';
}
