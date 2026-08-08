import 'package:pozzy_bot/config/config_validator.dart';
import 'package:pozzy_bot/config/env_file_service.dart';
import 'package:pozzy_bot/database/database.dart';
import 'package:pozzy_bot/database/repositories/user_repositories.dart';
import 'package:pozzy_bot/handler/main_menu_handler.dart';
import 'package:pozzy_bot/handler/register_handler.dart';
import 'package:pozzy_bot/handler/reply_handler.dart';
import 'package:pozzy_bot/handler/start_handler.dart';
import 'package:pozzy_bot/router/callback_router.dart';
import 'package:pozzy_bot/services/telegram/menu_photo_service.dart';
import 'package:pozzy_bot/services/user_service.dart';
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

    final userService = UserService(userRepo);
    final start = StartHandler(userService, reply);
    final mainMenu = MainMenuHandler(reply, userService);
    final callbacks = CallbackRouter(users: userService, mainMenu: mainMenu);

    RegisterHandler.register(bot, start: start, callbackRouter: callbacks);
    await bot.api.setChatMenuButton(MenuButton.commands());
    BotLog.info('started @${bot.me.username} verbose=${BotLog.verbose}');
    await bot.start(
      LongPollingFetcher(bot.api, config: const LongPollingConfig.lowLatency()),
    );
  }
}
