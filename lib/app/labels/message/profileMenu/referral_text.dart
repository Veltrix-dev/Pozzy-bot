import 'package:pozzy_bot/app/labels/format/emoji.dart';
import 'package:pozzy_bot/app/labels/format/html_format.dart';
import 'package:pozzy_bot/app/labels/format/money_formatter.dart';
import 'package:pozzy_bot/database/models/referral_stats.dart';

abstract final class ReferralText {
  static String build({
    required String referralLink,
    required String referralPercent,
  }) {
    return '''
${Emoji.referrals}Рефералы:

<blockquote>Приглашайте друзей и получайте $referralPercent% от каждой покупки ваших рефералов:

${Emoji.link} Ваша ссылка:
${HtmlFormat.link(referralLink, referralLink)}</blockquote>

${Emoji.menu} Управление доступно через меню ниже:
'''
        .trim();
  }

  static String buildReferralsList(ReferralStats stats) {
    if (stats.referrals.isEmpty) {
      return '${Emoji.profile2}Список рефералов:\n\nПока никого нет';
    }

    final lines = stats.referrals.map(_line).join('\n');
    return '''
${Emoji.profile2} Список рефералов:

$lines
'''.trim();
  }

  static const copyLinkButton = 'Скопировать ссылку';

  static const shareButton = 'Поделиться';

  static const referralsListButton = 'Список рефералов';

  static const shareInlineTitle = 'Пригласить в бота';

  static String shareInlineDescription({required String link}) => link;

  static const openReferralLinkButton = 'Открыть бота';

  static String shareMessage({required String link}) =>
      'Присоединяйся к Pozzy Stars!\n\n$link';

  static String newReferralNotification({
    required String referralLabel,
  }) =>
      '${Emoji.profile3} Новый реферал: $referralLabel';

  static String purchaseCommissionNotification({
    required String referralLabel,
    required String purchaseAmount,
    required String referralPercent,
    required String commissionAmount,
    required String balance,
  }) =>
      '${Emoji.referralsBalance} Ваш реферал $referralLabel пополнил баланс '
      'на ${HtmlFormat.bold('$purchaseAmount \$')}:\n'
      'Вам начислено $referralPercent% : ${HtmlFormat.bold('$commissionAmount \$')}\n'
      'Баланс: ${HtmlFormat.bold('$balance \$')}';

  static String userLabel({required int telegramId, String? username}) {
    final trimmed = username?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      return '@${HtmlFormat.escape(trimmed)}';
    }
    return HtmlFormat.code(telegramId.toString());
  }

  static String _line(ReferralEntry entry) {
    final label = userLabel(
      telegramId: entry.telegramId,
      username: entry.username,
    );
    return '$label · ${MoneyFormatter.compact(entry.commissionAmount)}\$';
  }
}
