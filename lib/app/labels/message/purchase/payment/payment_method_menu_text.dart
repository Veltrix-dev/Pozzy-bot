import 'package:pozzy_bot/app/labels/format/emoji.dart';
import 'package:pozzy_bot/app/labels/message/purchase/common/fragment_payment_text.dart';

abstract final class PaymentMethodMenuText {
  static final menu =
      '''
${Emoji.wallet}Выберите способ оплаты:

<blockquote>Доступные способы оплаты:
TON
Криптовалюта</blockquote>

${FragmentPaymentText.inDevelopment}

${Emoji.menu}Управление доступно через меню ниже:
'''
          .trim();
}
