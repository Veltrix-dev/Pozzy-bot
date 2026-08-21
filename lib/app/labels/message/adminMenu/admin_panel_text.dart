import 'package:pozzy_bot/app/labels/format/html_format.dart';
import 'package:pozzy_bot/database/models/admin_statistics.dart';
import 'package:pozzy_bot/database/models/admin_user_snapshot.dart';

abstract final class AdminPanelText {
  static const panel = '''
<b>Админ-панель</b>

<blockquote>Доступ разрешён только Telegram ID из ADMIN_IDS. Все критические действия требуют отдельного подтверждения.</blockquote>

Выберите действие:
''';

  static const accessDenied = 'Нет доступа к админ-панели.';

  static const userQueryPrompt = '''
<b>Информация о пользователе</b>

Отправьте Telegram ID или username пользователя.
''';

  static const topUpTargetPrompt = '''
<b>Пополнение баланса</b>

Отправьте Telegram ID или username пользователя.
''';

  static String topUpAmountPrompt(AdminUserSnapshot target) =>
      '''
<b>Пополнение баланса</b>

Пользователь: ${_userLabel(target)}
Текущий баланс: <b>${_usd(target.balanceMicros)}</b>

Отправьте сумму пополнения в USD.
''';

  static String topUpConfirmation(AdminUserSnapshot target, int amountMicros) =>
      '''
<b>Подтвердите пополнение</b>

Пользователь: ${_userLabel(target)}
Сумма: <b>${_usd(amountMicros)}</b>
Баланс до операции: <b>${_usd(target.balanceMicros)}</b>

После подтверждения операция будет записана в журнал.
''';

  static const broadcastPrompt = '''
<b>Рассылка</b>

Отправьте одно сообщение для рассылки. Поддерживаются текст, фото, видео и другие типы сообщений Telegram.
''';

  static String broadcastConfirmation(int recipients) =>
      '''
<b>Подтвердите рассылку</b>

Получателей в базе: <b>$recipients</b>.
Сообщение будет скопировано без пересылочной подписи.
''';

  static String administrators(Iterable<int> ids) {
    final values = ids.toList();
    final body = values.isEmpty
        ? 'ADMIN_IDS не содержит корректных Telegram ID.'
        : values.map((id) => '• <code>$id</code>').join('\n');
    return '''
<b>Администраторы из .env</b>

$body

Изменение списка применяется только после редактирования <code>ADMIN_IDS</code> и перезапуска бота.
''';
  }

  static String statistics(AdminStatistics value) =>
      '''
<b>Статистика бота</b>

<b>Пользователи</b>
Всего: ${value.users.total}
За сутки: ${value.users.lastDay}
За 7 дней: ${value.users.lastWeek}
За 30 дней: ${value.users.lastMonth}

<b>Покупки</b>
Stars: ${value.stars.count} · ${_quantity(value.stars.quantity)} шт. · ${_usd(value.stars.spentUsdMicros)}
Premium: ${value.premium.count} · ${_usd(value.premium.spentUsdMicros)}
TON: ${value.ton.count} · ${_quantity(value.ton.quantity)} TON · ${_usd(value.ton.spentUsdMicros)}
Подарки: ${value.gifts.count} · ${_usd(value.gifts.spentUsdMicros)}

Ожидают завершения: ${value.pendingOrders}
Завершились ошибкой: ${value.failedOrders}

<b>Рефералы</b>
Всего связей: ${value.referrals.total}
За сутки: ${value.referrals.lastDay}
За 7 дней: ${value.referrals.lastWeek}
За 30 дней: ${value.referrals.lastMonth}

Баланс всех пользователей: <b>${_usd(value.totalBalanceMicros)}</b>
Сформировано: ${_date(value.generatedAt)} UTC
''';

  static String userInfo(AdminUserSnapshot value) {
    final username = value.user.username == null
        ? 'не указан'
        : '@${HtmlFormat.escape(value.user.username!)}';
    return '''
<b>Пользователь</b>

Telegram ID: <code>${value.user.telegramId}</code>
Username: $username
Роль в БД: ${HtmlFormat.escape(value.user.role)}
Зарегистрирован: ${_date(value.user.createdAt)} UTC

Баланс: <b>${_usd(value.balanceMicros)}</b>
Покупок: ${value.purchasesCount}
Сумма покупок: ${_usd(value.purchasesTotalMicros)}
Приглашено пользователей: ${value.invitedCount}
''';
  }

  static String _userLabel(AdminUserSnapshot value) {
    final username = value.user.username;
    if (username == null || username.isEmpty) {
      return '<code>${value.user.telegramId}</code>';
    }
    return '@${HtmlFormat.escape(username)} (<code>${value.user.telegramId}</code>)';
  }

  static String _usd(int micros) {
    final whole = micros ~/ 1000000;
    final fraction = (micros % 1000000).toString().padLeft(6, '0');
    final trimmed = fraction.replaceFirst(RegExp(r'0+$'), '');
    return trimmed.isEmpty ? '\$$whole' : '\$$whole.$trimmed';
  }

  static String _quantity(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(3).replaceFirst(RegExp(r'0+$'), '');

  static String _date(DateTime value) {
    final utc = value.toUtc();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(utc.day)}.${two(utc.month)}.${utc.year} '
        '${two(utc.hour)}:${two(utc.minute)}';
  }
}
