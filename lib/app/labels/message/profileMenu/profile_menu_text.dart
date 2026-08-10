import 'package:pozzy_bot/app/labels/format/emoji.dart';
import 'package:pozzy_bot/app/labels/format/html_format.dart';
import 'package:pozzy_bot/app/labels/format/money_formatter.dart';

abstract final class ProfileMenuText {
  static String build({
    int invitedCount = 0,
    double earnedCommission = 0.0,
    required double balance,
  }) {
    final formattedBalance = MoneyFormatter.compact(balance);
    final formattedCommission = MoneyFormatter.compact(earnedCommission);

    return '''
${Emoji.profile}Личный кабинет:

<blockquote>${Emoji.balance}Баланс: $formattedBalance\$
${Emoji.profile2}Приглашено рефералов: $invitedCount
${Emoji.earned}Заработано с рефералов: $formattedCommission\$</blockquote>

${Emoji.menu} Управление доступно через меню ниже:
'''.trim();
  }
}
