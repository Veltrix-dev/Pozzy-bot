import 'package:pozzy_bot/config/config.dart';
import 'package:televerse/televerse.dart';

class ConfigValidator {


static Future<Bot<Context>> validateBotToken() async {
  try {
    final bot = Bot<Context>(Config.botToken);
    await bot.initialize();
    print('this token is valid!');
    return bot;
  }catch(e) {
    print('Telegram token validation failed: $e');
    throw StateError('ERROR: Token not found');
  }
}
}