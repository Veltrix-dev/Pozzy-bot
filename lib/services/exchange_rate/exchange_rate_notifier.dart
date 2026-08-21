import 'package:pozzy_bot/app/labels/message/exchange_rate/exchange_rate_admin_text.dart';
import 'package:pozzy_bot/handler/reply_handler.dart';
import 'package:pozzy_bot/services/exchange_rate/exchange_rate_store.dart';
import 'package:pozzy_bot/utils/bot_log.dart';
import 'package:televerse/televerse.dart';

abstract interface class ExchangeRateNotifier {
  Future<void> notifyFallbackActivated({
    required StoredExchangeRate fallback,
    StoredExchangeRate? primary,
  });

  Future<void> notifyEmergencyRateActivated(StoredExchangeRate stored);

  Future<void> notifyPrimaryRestored(StoredExchangeRate primary);

  Future<void> notifyUnavailable(String reason);

  Future<void> notifyRateRejected({
    required ExchangeRateSource source,
    required String reason,
  });
}

class SilentExchangeRateNotifier implements ExchangeRateNotifier {
  const SilentExchangeRateNotifier();

  @override
  Future<void> notifyFallbackActivated({
    required StoredExchangeRate fallback,
    StoredExchangeRate? primary,
  }) async {}

  @override
  Future<void> notifyEmergencyRateActivated(StoredExchangeRate stored) async {}

  @override
  Future<void> notifyPrimaryRestored(StoredExchangeRate primary) async {}

  @override
  Future<void> notifyUnavailable(String reason) async {}

  @override
  Future<void> notifyRateRejected({
    required ExchangeRateSource source,
    required String reason,
  }) async {}
}

class ExchangeRateAdminNotifier implements ExchangeRateNotifier {
  ExchangeRateAdminNotifier({
    required ReplyHandler reply,
    required Set<int> adminTelegramIds,
  }) : _reply = reply,
       _adminTelegramIds = adminTelegramIds;

  final ReplyHandler _reply;
  final Set<int> _adminTelegramIds;

  @override
  Future<void> notifyFallbackActivated({
    required StoredExchangeRate fallback,
    StoredExchangeRate? primary,
  }) {
    return _send(
      ExchangeRateAdminText.fallbackActivated(
        fallback: fallback,
        primary: primary,
      ),
    );
  }

  @override
  Future<void> notifyEmergencyRateActivated(StoredExchangeRate stored) {
    return _send(ExchangeRateAdminText.emergencyRateActivated(stored));
  }

  @override
  Future<void> notifyPrimaryRestored(StoredExchangeRate primary) {
    return _send(ExchangeRateAdminText.primaryRestored(primary));
  }

  @override
  Future<void> notifyUnavailable(String reason) {
    return _send(ExchangeRateAdminText.unavailable(reason));
  }

  @override
  Future<void> notifyRateRejected({
    required ExchangeRateSource source,
    required String reason,
  }) {
    return _send(
      ExchangeRateAdminText.rateRejected(source: source, reason: reason),
    );
  }

  Future<void> _send(String text) async {
    for (final telegramId in _adminTelegramIds) {
      try {
        await _reply.sendText(ChatID(telegramId), text);
      } catch (error, stackTrace) {
        BotLog.error(
          'exchange_rate admin_notification_failed admin=$telegramId '
          'error=${error.runtimeType}',
        );
        if (BotLog.verbose) BotLog.debug(stackTrace.toString());
      }
    }
  }
}
