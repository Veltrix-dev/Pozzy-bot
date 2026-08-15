import 'package:pozzy_bot/services/exchange_rate/exchange_rate_store.dart';

abstract final class ExchangeRateAdminText {
  static String fallbackActivated({
    required StoredExchangeRate fallback,
    StoredExchangeRate? primary,
  }) =>
      '<b>Включён резервный курс USD/RUB</b>\n\n'
      'Twelve Data не обновлялся более 2 часов. '
      'Продажи продолжаются по курсу ExchangeRate-API.\n\n'
      'Резервный курс: <b>${_rate(fallback.rate)}₽</b>\n'
      'Обновлён: <b>${_date(fallback.sourceUpdatedAt)}</b>\n'
      '${primary == null ? '' : 'Последний Twelve Data: <b>${_rate(primary.rate)}₽</b>\n'}'
      'Необходимо проверить Twelve Data или обратиться к разработчику.';

  static String emergencyRateActivated(StoredExchangeRate stored) =>
      '<b>Аварийный режим курса USD/RUB</b>\n\n'
      'Twelve Data не обновлялся более 2 часов, а свежий запрос к '
      'ExchangeRate-API не выполнен. Продажи продолжаются по последнему '
      'подтверждённому курсу.\n\n'
      'Источник: <b>${_source(stored.source)}</b>\n'
      'Курс: <b>${_rate(stored.rate)}₽</b>\n'
      'Получен: <b>${_date(stored.fetchedAt)}</b>\n\n'
      'Необходимо срочно проверить сервисы курса или обратиться к разработчику.';

  static String primaryRestored(StoredExchangeRate primary) =>
      '<b>Twelve Data восстановлен</b>\n\n'
      'Основной курс USD/RUB снова обновляется.\n'
      'Текущий курс: <b>${_rate(primary.rate)}₽</b>\n'
      'Получен: <b>${_date(primary.fetchedAt)}</b>.';

  static String _source(ExchangeRateSource source) => switch (source) {
    ExchangeRateSource.twelveData => 'Twelve Data',
    ExchangeRateSource.exchangeRateApi => 'ExchangeRate-API',
  };

  static String _rate(double value) => value.toStringAsFixed(4);

  static String _date(DateTime value) => value.toUtc().toIso8601String();
}
