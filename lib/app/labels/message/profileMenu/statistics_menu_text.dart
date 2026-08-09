import 'package:pozzy_bot/app/labels/format/date_formatter.dart';
import 'package:pozzy_bot/app/labels/format/money_formatter.dart';
import 'package:pozzy_bot/app/labels/format/username_formatter.dart';
import 'package:pozzy_bot/database/models/referral_stats.dart';
import 'package:pozzy_bot/database/models/user.dart';
import 'package:pozzy_bot/database/models/user_statistics.dart';

abstract final class StatisticsMenuText {
  static String build({
    required User user,
    required UserStatistics stats,
    required ReferralStats referralStats,
    required String referralPercent,
    required double balance,
  }) {
    return '''
Статистика

Профиль
ID: ${user.telegramId}
${UsernameFormatter.optionalLine(user.username)}В боте с: ${DateFormatter.shortDate(user.createdAt)}

Покупки
Количество: ${stats.purchasesCount}
Сумма: ${MoneyFormatter.fixed(stats.purchasesTotal)}

Рефералы
Всего приглашено: ${referralStats.invitedCount}
Процент с покупок: $referralPercent%
Заработано с рефералов: ${MoneyFormatter.fixed(referralStats.commissionTotal)}
Баланс к выводу: ${MoneyFormatter.fixed(balance)}
'''
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }
}
