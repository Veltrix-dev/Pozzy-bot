import 'package:pozzy_bot/app/labels/format/date_formatter.dart';
import 'package:pozzy_bot/app/labels/format/percent_formatter.dart';
import 'package:pozzy_bot/app/labels/id/premium_emoji_ids.dart';
import 'package:pozzy_bot/config/config.dart';
import 'package:pozzy_bot/database/models/referral_stats.dart';
import 'package:pozzy_bot/database/models/user.dart';
import 'package:pozzy_bot/database/models/user_statistics.dart';
import 'package:pozzy_bot/services/telegram/rich_message_html.dart';

abstract final class StatisticsMenuText {
  static String build({
    required User user,
    required UserStatistics stats,
    required ReferralStats referralStats,
  }) {
    final referralPercent = PercentFormatter.format(
      Config.referralPurchasePercent,
    );

    final blocks = <String>[
      _block(['${_emoji(PremiumEmojiIds.statistics)} Статистика:']),
      _block([
        '${_emoji(PremiumEmojiIds.profile)} ID: `${user.telegramId}` · ${_username(user.username)}',
        '${_emoji(PremiumEmojiIds.time)} С нами: ${DateFormatter.shortDate(user.createdAt)} (${_daysInBot(user.createdAt)})',
      ]),
      _block([
        '${_emoji(PremiumEmojiIds.balance)} Финансы',
        'Потрачено: ${_usd(stats.purchasesTotal)}',
      ]),
      _block([
        '${_emoji(PremiumEmojiIds.referrals)} Рефералы',
        'Всего рефералов: ${referralStats.invitedCount}',
        'Заработано монет за рефералов: ${_amount(referralStats.registrationCoinsEarned)} PXC',
        'Доход с покупок рефералов ($referralPercent%): ${_usd(referralStats.commissionTotal)}',
      ]),
      _block([
        '${_emoji(PremiumEmojiIds.boxstars)} Активность:',
        ..._starsLines(stats.starsPurchases),
        ..._premiumLines(stats.premiumPurchases),
        ..._tonLines(stats.tonPurchases),
      ]),
    ];

    return blocks.join('<br><br>');
  }

  static List<String> _starsLines(List<UserPurchaseEntry> purchases) {
    return [
      '${_emoji(PremiumEmojiIds.stars)} Stars:',
      if (purchases.isEmpty)
        'Пока нет покупок'
      else
        for (final purchase in purchases)
          '${DateFormatter.shortDate(purchase.purchasedAt)} · ${purchase.quantity.round()} ${_emoji(PremiumEmojiIds.stars)} · ${_usd(purchase.spentUsd)}',
    ];
  }

  static List<String> _premiumLines(List<UserPurchaseEntry> purchases) {
    return [
      '${_emoji(PremiumEmojiIds.premium)} Premium:',
      if (purchases.isEmpty)
        'Пока нет покупок'
      else
        for (final purchase in purchases)
          '${DateFormatter.shortDate(purchase.purchasedAt)} · ${purchase.quantity.round()} мес. · ${_usd(purchase.spentUsd)}',
    ];
  }

  static List<String> _tonLines(List<UserPurchaseEntry> purchases) {
    return [
      '${_emoji(PremiumEmojiIds.ton)} TON:',
      if (purchases.isEmpty)
        'Пока нет покупок'
      else
        for (final purchase in purchases)
          '${DateFormatter.shortDate(purchase.purchasedAt)} · ${_quantity(purchase.quantity)} TON · ${_usd(purchase.spentUsd)}',
    ];
  }

  static String _block(List<String> lines) => lines.join('<br>');

  static String _emoji(String emojiId) =>
      RichMessageHtml.emojiMarkdown(emojiId);

  static String _username(String? username) {
    final value = username?.trim();
    if (value == null || value.isEmpty) return '—';
    return '@${value.replaceAll('_', r'\_')}';
  }

  static String _usd(double amount) => '${_amount(amount)}${r'\$'}';

  static String _amount(double amount) {
    if (amount == amount.roundToDouble()) return amount.toStringAsFixed(0);
    var formatted = amount.toStringAsFixed(3);
    while (formatted.endsWith('0') && formatted.split('.')[1].length > 2) {
      formatted = formatted.substring(0, formatted.length - 1);
    }
    return formatted;
  }

  static String _quantity(double amount) {
    if (amount == amount.roundToDouble()) return amount.toStringAsFixed(0);
    return amount.toStringAsFixed(2);
  }

  static String _daysInBot(DateTime createdAt) {
    final days = DateTime.now().toUtc().difference(createdAt.toUtc()).inDays;
    return '$days ${_daysWord(days)}';
  }

  static String _daysWord(int days) {
    final mod10 = days % 10;
    final mod100 = days % 100;
    if (mod10 == 1 && mod100 != 11) return 'день';
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 10 || mod100 >= 20)) {
      return 'дня';
    }
    return 'дней';
  }
}
