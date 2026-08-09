import 'package:pozzy_bot/app/labels/format/duration_formatter.dart';
import 'package:pozzy_bot/app/labels/format/emoji.dart';
import 'package:pozzy_bot/app/labels/format/html_format.dart';

abstract final class ProfileMenuText {
  static String build({
    required int telegramId,
    required String? username,
    required DateTime createdAt,
    int invitedCount = 0,
    double earnedCommission = 0.0,
    DateTime? now, required String referralPercent, required String balance,
  }) {
    final formattedUsername = _formatUsername(username);
    final withUsText = DurationFormatter.formatPeriod(createdAt, now: now);
    final formattedCommission = _formatMoney(earnedCommission);

    return '''
<b>Мой профиль</b>

ID: ${HtmlFormat.code(telegramId.toString())}
Username: $formattedUsername
С нами: $withUsText

${Emoji.profile2}Приглашено рефералов: $invitedCount
Заработано с рефералов: $formattedCommission\$

${Emoji.menu} Управление доступно через меню ниже:
'''.trim();
  }

  static String _formatUsername(String? username) {
    if (username == null) return '—';
    final trimmed = username.trim();
    if (trimmed.isEmpty) return '—';
    return '@${HtmlFormat.escape(trimmed)}';
  }

  static String _formatMoney(double amount) {
    if (amount == amount.roundToDouble()) {
      return amount.toInt().toString();
    }
    return amount.toStringAsFixed(2);
  }
}