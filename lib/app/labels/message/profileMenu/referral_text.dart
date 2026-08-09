import 'package:pozzy_bot/app/labels/format/html_format.dart';
import 'package:pozzy_bot/app/labels/format/money_formatter.dart';
import 'package:pozzy_bot/database/models/referral_stats.dart';

abstract final class ReferralText {
  static String build({
    required String referralLink,
    required String referralPercent,
  }) {
    return '''
<b>Реферальная программа</b>

Вы получаете $referralPercent% от всех покупок ваших рефералов.

Ваша ссылка:
${HtmlFormat.link(referralLink, referralLink)}
'''
        .trim();
  }

  static String buildReferralsList(ReferralStats stats) {
    if (stats.referrals.isEmpty) {
      return '<b>Список рефералов</b>\n\nПока никого нет.';
    }

    final lines = stats.referrals.map(_line).join('\n');
    return '<b>Список рефералов</b>\n\n$lines';
  }

  static String _line(ReferralEntry entry) {
    final label = entry.username == null || entry.username!.trim().isEmpty
        ? HtmlFormat.code(entry.telegramId.toString())
        : '@${HtmlFormat.escape(entry.username!)}';
    return '$label · комиссия: ${MoneyFormatter.fixed(entry.commissionAmount)}';
  }
}
