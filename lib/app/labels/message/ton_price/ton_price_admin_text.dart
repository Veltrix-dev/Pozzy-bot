import 'package:pozzy_bot/app/labels/format/html_format.dart';

abstract final class TonPriceAdminText {
  static String sourceFailure({
    required String reason,
    required String fallback,
  }) {
    return '<b>Ошибка получения курса TON/USD</b>\n\n'
        'Причина: ${HtmlFormat.code(reason)}\n'
        'Используется: <b>$fallback</b>.';
  }

  static String unavailable(String reason) =>
      '<b>Курс TON/USD недоступен</b>\n\n'
      'Причина: ${HtmlFormat.code(reason)}\n'
      'Свежего курса в SQLite и актуального fallback в .env нет. '
      'Покупка TON временно недоступна.';

  static String storageFailure({
    required String operation,
    required String reason,
  }) =>
      '<b>Ошибка кеша курса TON/USD</b>\n\n'
      'Операция: <b>$operation SQLite</b>\n'
      'Причина: ${HtmlFormat.code(reason)}.';
}
