import 'package:pozzy_bot/app/labels/button/mainMenu/click_button.dart';
import 'package:pozzy_bot/app/labels/format/percent_formatter.dart';
import 'package:pozzy_bot/app/labels/message/profileMenu/profile_menu_text.dart';
import 'package:pozzy_bot/app/labels/message/profileMenu/referral_text.dart';
import 'package:pozzy_bot/app/labels/message/profileMenu/statistics_menu_text.dart';
import 'package:pozzy_bot/config/config.dart';
import 'package:pozzy_bot/database/models/user.dart';
import 'package:pozzy_bot/handler/reply_handler.dart';
import 'package:pozzy_bot/keyboards/profileMenu/profile_menu_keyboard.dart';
import 'package:pozzy_bot/keyboards/profileMenu/referral_keyboard.dart';
import 'package:pozzy_bot/services/balance_service.dart';
import 'package:pozzy_bot/services/referral/referral_service.dart';
import 'package:pozzy_bot/services/telegram/menu_photo_key.dart';
import 'package:pozzy_bot/services/telegram/rich_message_html.dart';
import 'package:pozzy_bot/services/user_service.dart';
import 'package:pozzy_bot/services/user_statistics_service.dart';
import 'package:televerse/televerse.dart';

class MainMenuHandler {
  MainMenuHandler({
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

  Future<void> onNews(Context ctx) async {
    await _reply.sendMenuWithPhoto(
      ctx.id,
      photo: MenuPhotoKey.newsProject,
      text: ClickButton.news,
    );
  }

  Future<void> onChat(Context ctx) async {
    await _reply.sendMenuWithPhoto(
      ctx.id,
      photo: MenuPhotoKey.chatProject,
      text: ClickButton.chat,
    );
  }

  Future<void> onSupport(Context ctx) async {
    await _reply.sendMenuWithPhoto(
      ctx.id,
      photo: MenuPhotoKey.support,
      text: ClickButton.support,
    );
  }

  Future<void> onProfile(Context ctx) async {
    final user = await _userFromContext(ctx);
    if (user == null) return;

    final referralStats = _referrals.statsForUser(user);
    final userBalance = _balance.getBalance(user.telegramId);
    await _reply.sendText(
      ctx.id,
      ProfileMenuText.build(
        invitedCount: referralStats.invitedCount,
        earnedCommission: referralStats.commissionTotal,
        balance: userBalance.balance,
      ),
      replyMarkup: ProfileMenuKeyboard().markup,
    );
  }

  Future<void> onReferrals(Context ctx) async {
    final user = await _userFromContext(ctx);
    if (user == null) return;

    final referralLink = _referrals.buildReferralLink(user);
    await _reply.sendText(
      ctx.id,
      ReferralText.build(
        referralLink: referralLink,
        referralPercent: PercentFormatter.format(
          Config.referralPurchasePercent,
        ),
      ),
      replyMarkup: ReferralKeyboard(
        referralLink: referralLink,
        referralCode: user.referralCode,
      ).markup,
    );
  }

  Future<void> onReferralsList(Context ctx) async {
    final user = await _userFromContext(ctx);
    if (user == null) return;

    await _reply.sendText(
      ctx.id,
      ReferralText.buildReferralsList(_referrals.statsForUser(user)),
    );
  }

  Future<void> onStatistics(Context ctx) async {
    final user = await _userFromContext(ctx);
    final from = ctx.from;
    if (user == null || from == null) return;

    await _reply.sendRichMessageWithDraft(
      ctx.id,
      draftHtml: RichMessageHtml.thinking('Собираю статистику…'),
      skipEntityDetection: true,
      buildContent: () async => StatisticsMenuText.build(
        user: user,
        stats: _statistics.buildForUser(from.id),
        referralStats: _referrals.statsForUser(user),
      ),
    );
  }

  Future<User?> _userFromContext(Context ctx) async {
    final from = ctx.from;
    if (from == null) return null;
    return _users.getOrCreate(telegramId: from.id, username: from.username);
  }
}
