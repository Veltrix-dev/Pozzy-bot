import 'package:pozzy_bot/config/config.dart';
import 'package:pozzy_bot/config/config_validator.dart';
import 'package:pozzy_bot/config/env_file_service.dart';
import 'package:pozzy_bot/database/database.dart';
import 'package:pozzy_bot/database/repositories/referral_repository.dart';
import 'package:pozzy_bot/database/repositories/user_balance_repository.dart';
import 'package:pozzy_bot/database/repositories/user_statistics_repository.dart';
import 'package:pozzy_bot/database/repositories/user_repositories.dart';
import 'package:pozzy_bot/handler/main_menu_handler.dart';
import 'package:pozzy_bot/handler/register_handler.dart';
import 'package:pozzy_bot/handler/referral_inline_query_handler.dart';
import 'package:pozzy_bot/handler/reply_handler.dart';
import 'package:pozzy_bot/handler/start_handler.dart';
import 'package:pozzy_bot/router/callback_router.dart';
import 'package:pozzy_bot/services/balance_service.dart';
import 'package:pozzy_bot/services/referral/referral_service.dart';
import 'package:pozzy_bot/services/referral/referral_notification_service.dart';
import 'package:pozzy_bot/services/telegram/menu_photo_service.dart';
import 'package:pozzy_bot/services/user_service.dart';
import 'package:pozzy_bot/services/user_statistics_service.dart';
import 'package:pozzy_bot/utils/bot_log.dart';
import 'package:televerse/telegram.dart';
import 'package:televerse/televerse.dart';

abstract class Bootstrap {
  static Future<void> run() async {
    final bot = await ConfigValidator.validateBotToken();
    await AppDatabase.init();

    await bot.api.setMyCommands([
      BotCommand(command: 'start', description: 'Главное меню'),
    ]);

    final envFileService = EnvFileService();
    final menuPhotoService = MenuPhotoService(envFile: envFileService);
    final reply = ReplyHandler(bot, menuPhotos: menuPhotoService);
    final userRepo = UserRepositories();
    final referralRepo = ReferralRepository();
    final statisticsRepo = UserStatisticsRepository();
    final balanceRepo = UserBalanceRepository();

    final userService = UserService(userRepo);
    final statisticsService = UserStatisticsService(statisticsRepo);
    final balanceService = BalanceService(balanceRepo);
    final referralNotifications = ReferralNotificationService(
      reply: reply,
      users: userRepo,
      balance: balanceService,
    );
    final referralService = ReferralService(
      repo: referralRepo,
      users: userRepo,
      botUsername: Config.botUsername.isEmpty
          ? (bot.me.username ?? '')
          : Config.botUsername,
      notifications: referralNotifications,
    );
    final start = StartHandler(userService, reply, referralService);
    final referralInlineQuery = ReferralInlineQueryHandler(referralService);
    final mainMenu = MainMenuHandler(
      reply: reply,
      users: userService,
      statistics: statisticsService,
      referrals: referralService,
      balance: balanceService,
    );
    final callbacks = CallbackRouter(mainMenu: mainMenu);

    RegisterHandler.register(
      bot,
      start: start,
      callbackRouter: callbacks,
      referralInlineQuery: referralInlineQuery,
    );
    await bot.api.setChatMenuButton(MenuButton.commands());
    BotLog.info('started @${bot.me.username} verbose=${BotLog.verbose}');
    await bot.start(
      LongPollingFetcher(bot.api, config: const LongPollingConfig.lowLatency()),
    );
  }
}
