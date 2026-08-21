import 'package:pozzy_bot/services/exchange_rate/exchange_rate_store.dart';

abstract final class ExchangeRateAdminText {
  static String fallbackActivated({
    required StoredExchangeRate fallback,
    StoredExchangeRate? primary,
  }) =>
      '<b>Включён резервный курс USD/RUB</b>\n\n'
      'Основной курс Twelve Data больше не отвечает требованиям актуальности. '
      'Продажи продолжаются по курсу ExchangeRate-API.\n\n'
      'Резервный курс: <b>${_rate(fallback.rate)}₽</b>\n'
      'Обновлён: <b>${_date(fallback.sourceUpdatedAt)}</b>\n'
      '${primary == null ? '' : 'Последний Twelve Data: <b>${_rate(primary.rate)}₽</b>\n'}'
      'Необходимо проверить Twelve Data или обратиться к разработчику.';

  static String emergencyRateActivated(StoredExchangeRate stored) =>
      '<b>Аварийный режим курса USD/RUB</b>\n\n'
      'Основной курс Twelve Data устарел, а свежий запрос к '
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

  static String unavailable(String reason) =>
      '<b>Курс USD/RUB недоступен</b>\n\n'
      'Нет курса, который проходит ограничения актуальности и безопасности. '
      'Продажи в рублях должны быть временно остановлены.\n\n'
      'Причина: <b>$reason</b>.\n'
      'Необходимо проверить поставщиков курса и состояние базы данных.';

  static String rateRejected({
    required ExchangeRateSource source,
    required String reason,
  }) =>
      '<b>Отклонён курс USD/RUB</b>\n\n'
      'Источник: <b>${_source(source)}</b>\n'
      'Причина: <b>$reason</b>.\n\n'
      'Последний подтверждённый курс не был заменён.';

  static String _source(ExchangeRateSource source) => switch (source) {
    ExchangeRateSource.twelveData => 'Twelve Data',
    ExchangeRateSource.exchangeRateApi => 'ExchangeRate-API',
  };

  static String _rate(double value) => value.toStringAsFixed(4);

  static String _date(DateTime value) => value.toUtc().toIso8601String();
}
