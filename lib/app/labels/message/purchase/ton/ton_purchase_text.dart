import 'package:pozzy_bot/app/labels/format/emoji.dart';
import 'package:pozzy_bot/app/labels/format/html_format.dart';
import 'package:pozzy_bot/app/labels/format/money_formatter.dart';
import 'package:pozzy_bot/database/models/rub_amount.dart';
import 'package:pozzy_bot/database/models/ton_amount.dart';
import 'package:pozzy_bot/database/models/ton_wallet_transfer.dart';
import 'package:pozzy_bot/services/fragment/fragment_pricing_service.dart';

abstract final class TonPurchaseText {
  static final menu =
      '''
${Emoji.ton}Покупка TON:

<blockquote>Вы можете получить их на Telegram-аккаунт или отправить на TON-кошелёк

${Emoji.menu}Управление доступно через меню ниже:</blockquote>
'''
          .trim();

  static final invalidAmount =
      'Некорректное количество TON${Emoji.exclamationMark}';

  static const backButtonText = 'Назад';
  static const telegram = 'На аккаунт Telegram';
  static const wallet = 'На TON-кошелёк';

  static String telegramAccount(RubAmount tonRubRate) =>
      '''
${Emoji.ton}Отправка TON на аккаунт:

<blockquote>Актуальный курс: 1 TON = ${_rub(tonRubRate)} ₽
Минимальная сумма: 1 TON

Введите количество TON, которое нужно отправить на аккаунт:</blockquote>

'''
          .trim();

  static String tonWallet(RubAmount tonRubRate) =>
      '''
${Emoji.ton}Отправка TON на кошелёк:

<blockquote>Актуальный курс: 1 TON = ${_rub(tonRubRate)} ₽
Минимальная сумма: 1 TON

Введите количество TON, которое нужно отправить на кошелёк:</blockquote>
'''
          .trim();

  static final walletAddressPrompt =
      '${Emoji.wallet}Введите адрес TON-кошелька:';

  static final invalidWalletAddress =
      'Некорректный адрес TON-кошелька${Emoji.exclamationMark2}\n'
      'Проверьте адрес и отправьте его ещё раз';

  static final transferFailed = 'Не удалось выполнить перевод TON${Emoji.sad}';

  static String rateExpired(RubAmount tonRubRate) =>
      'Срок предыдущего курса истёк\nНовый курс: '
      '<b>1 TON = ${_rub(tonRubRate)} ₽</b>\n\n'
      'Введите количество TON ещё раз';

  static String selected({
    required FragmentPriceQuote quote,
    required RubAmount tonRubRate,
    required RubAmount priceRub,
  }) {
    final amount = TonAmount.fromNano(quote.quantityUnits).toDecimalString();
    return '${Emoji.ton} Количество: <b>$amount TON</b>\n'
        'Курс: <b>1 TON = ${_rub(tonRubRate)} ₽</b>\n'
        'Стоимость: <b>${_rub(priceRub)} ₽</b>';
  }

  static String walletAmountSelected({
    required FragmentPriceQuote quote,
    required RubAmount tonRubRate,
    required RubAmount priceRub,
  }) =>
      '${selected(quote: quote, tonRubRate: tonRubRate, priceRub: priceRub)}'
      '\n\n$walletAddressPrompt';

  static String _rub(RubAmount amount) =>
      MoneyFormatter.fixedMicros(amount.micros);

  static String walletTransferCompleted(TonWalletTransfer transfer) =>
      '''
<b>Перевод TON выполнен</b>

Отправлено: <b>${transfer.amount.toDecimalString()} TON</b>
Кошелёк: ${HtmlFormat.code(transfer.recipientAddress)}
'''
          .trim();

  static String completed({
    required TonAmount amount,
    required String username,
  }) =>
      '<b>Покупка выполнена</b>\n\n'
      '${amount.toDecimalString()} TON отправлено получателю '
      '${HtmlFormat.code('@$username')}.';
}
