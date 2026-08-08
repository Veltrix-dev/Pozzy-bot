import 'package:pozzy_bot/config/config.dart';

abstract final class BotLog {
  static bool get verbose => Config.botVerboseLogging;

  static void info(String message) => print('[bot] INFO $message');

  static void event(String message) => print('[bot] $message');

  static void error(String message) => print('[bot] ERROR $message');

  static void debug(String message) {
    if (!verbose) return;
    print('[bot] DEBUG $message');
  }
}