import 'package:pozzy_bot/app/labels/format/emoji.dart';

abstract final class FragmentPurchaseResultText {
  static final serviceUnavailable =
      'Сервис покупки временно недоступен${Emoji.sad}';
  static const priceExpired = 'Цена устарела. Откройте меню покупки ещё раз.';
}
