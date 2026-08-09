import 'package:pozzy_bot/app/labels/format/money_formatter.dart';
import 'package:pozzy_bot/app/labels/format/percent_formatter.dart';
import 'package:pozzy_bot/app/labels/message/profileMenu/profile_menu_text.dart';
import 'package:pozzy_bot/app/labels/message/profileMenu/referral_text.dart';
import 'package:pozzy_bot/app/labels/message/profileMenu/statistics_menu_text.dart';
import 'package:pozzy_bot/config/config.dart';
import 'package:pozzy_bot/handler/reply_handler.dart';
import 'package:pozzy_bot/keyboards/profileMenu/profile_menu_keyboard.dart';
import 'package:pozzy_bot/keyboards/profileMenu/referral_keyboard.dart';
import 'package:pozzy_bot/services/balance_service.dart';
import 'package:pozzy_bot/services/referral_service.dart';
import 'package:pozzy_bot/services/user_service.dart';
import 'package:pozzy_bot/services/user_statistics_service.dart';
import 'package:televerse/televerse.dart';

class ProfileMenuHandler {
  ProfileMenuHandler({
    required ReplyHandler reply,
    required UserService users,
    required UserStatisticsService statistics,
    required ReferralService referrals,
    required BalanceService balance,
  }) : _reply = reply,
       _users = users,
       _statistics = statistics,
       _referrals = referrals,
       _balance = balance;

  final ReplyHandler _reply;
  final UserService _users;
  final UserStatisticsService _statistics;
  final ReferralService _referrals;
  final BalanceService _balance;

  Future<void> onProfile(Context ctx) async {
    final from = ctx.from;
    if (from == null) return;

    final user = await _users.getOrCreate(
      telegramId: from.id,
      username: from.username,
    );
    if (user == null) return;

    final referralStats = _referrals.statsForUser(user);
    final userBalance = _balance.getBalance(user.telegramId);

    await _reply.sendText(
      ctx.id,
      ProfileMenuText.build(
        telegramId: user.telegramId,
        username: user.username,
        createdAt: user.createdAt,
        invitedCount: referralStats.invitedCount,
        referralPercent: PercentFormatter.format(Config.referralPurchasePercent),
        balance: MoneyFormatter.compact(userBalance.balance),
      ),
      replyMarkup: ProfileMenuKeyboard().markup,
    );
  }

  Future<void> onReferrals(Context ctx) async {
    final from = ctx.from;
    if (from == null) return;

    final user = await _users.getOrCreate(
      telegramId: from.id,
      username: from.username,
    );
    if (user == null) return;

    final referralLink = _referrals.buildReferralLink(user);
    await _reply.sendText(
      ctx.id,
      ReferralText.build(
        referralLink: referralLink,
        referralPercent: PercentFormatter.format(Config.referralPurchasePercent),
      ),
      replyMarkup: ReferralKeyboard(referralLink: referralLink).markup,
    );
  }

  Future<void> onReferralsList(Context ctx) async {
    final from = ctx.from;
    if (from == null) return;

    final user = await _users.getOrCreate(
      telegramId: from.id,
      username: from.username,
    );
    if (user == null) return;

    final stats = _referrals.statsForUser(user);
    await _reply.sendText(ctx.id, ReferralText.buildReferralsList(stats));
  }

  Future<void> onStatistics(Context ctx) async {
    final from = ctx.from;
    if (from == null) return;

    final user = await _users.getOrCreate(
      telegramId: from.id,
      username: from.username,
    );
    if (user == null) return;

    await _reply.sendRichMessageWithDraft(
      ctx.id,
      draftHtml: '<b>Собираю статистику...</b>',
      useMarkdown: true,
      skipEntityDetection: true,
      buildContent: () async {
        final stats = _statistics.buildForUser(from.id);
        final referralStats = _referrals.statsForUser(user);
        final userBalance = _balance.getBalance(user.telegramId);

        return StatisticsMenuText.build(
          user: user,
          stats: stats,
          referralStats: referralStats,
          referralPercent: PercentFormatter.format(Config.referralPurchasePercent),
          balance: userBalance.balance,
        );
      },
    );
  }
}