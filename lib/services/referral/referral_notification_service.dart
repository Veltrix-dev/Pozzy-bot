import 'package:pozzy_bot/app/labels/format/money_formatter.dart';
import 'package:pozzy_bot/app/labels/format/percent_formatter.dart';
import 'package:pozzy_bot/app/labels/message/profileMenu/referral_text.dart';
import 'package:pozzy_bot/config/config.dart';
import 'package:pozzy_bot/database/models/referral_stats.dart';
import 'package:pozzy_bot/database/repositories/user_repositories.dart';
import 'package:pozzy_bot/handler/reply_handler.dart';
import 'package:pozzy_bot/services/balance_service.dart';
import 'package:pozzy_bot/utils/bot_log.dart';
import 'package:televerse/televerse.dart';

class ReferralNotificationService {
  ReferralNotificationService({
    required ReplyHandler reply,
    required UserRepositories users,
    required BalanceService balance,
  }) : _reply = reply,
       _users = users,
       _balance = balance;

  final ReplyHandler _reply;
  final UserRepositories _users;
  final BalanceService _balance;

  Future<void> notifyNewReferral({
    required int referrerTelegramId,
    required int referralTelegramId,
    String? referralUsername,
  }) {
    return _send(
      referrerTelegramId,
      ReferralText.newReferralNotification(
        referralLabel: ReferralText.userLabel(
          telegramId: referralTelegramId,
          username: referralUsername,
        ),
      ),
    );
  }

  Future<void> notifyPurchaseCommission(
    ReferralPurchaseCommissionResult commission,
  ) {
    final referral = _users.findByTelegramId(commission.referralTelegramId);
    final balance = _balance.getBalance(commission.referrerTelegramId);

    return _send(
      commission.referrerTelegramId,
      ReferralText.purchaseCommissionNotification(
        referralLabel: ReferralText.userLabel(
          telegramId: commission.referralTelegramId,
          username: referral?.username,
        ),
        purchaseAmount: MoneyFormatter.compact(commission.purchaseAmount),
        referralPercent: PercentFormatter.format(
          Config.referralPurchasePercent,
        ),
        commissionAmount: MoneyFormatter.compact(commission.commissionAmount),
        balance: MoneyFormatter.compact(balance.balance),
      ),
    );
  }

  Future<void> _send(int telegramId, String text) async {
    try {
      await _reply.sendText(ChatID(telegramId), text);
    } catch (error, stackTrace) {
      BotLog.error('referral notification failed for $telegramId: $error');
      if (BotLog.verbose) {
        BotLog.debug(stackTrace.toString());
      }
    }
  }
}
