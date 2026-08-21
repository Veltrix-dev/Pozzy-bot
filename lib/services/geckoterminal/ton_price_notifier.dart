import 'package:pozzy_bot/app/labels/message/ton_price/ton_price_admin_text.dart';
import 'package:pozzy_bot/handler/reply_handler.dart';
import 'package:pozzy_bot/utils/bot_log.dart';
import 'package:televerse/televerse.dart';

enum TonPriceFallbackSource { database, environment }

enum TonPriceStorageOperation { read, write }

abstract interface class TonPriceNotifier {
  Future<void> notifySourceFailure({
    required String reason,
    required TonPriceFallbackSource fallback,
  });

  Future<void> notifyUnavailable(String reason);

  Future<void> notifyStorageFailure({
    required TonPriceStorageOperation operation,
    required String reason,
  });
}

class SilentTonPriceNotifier implements TonPriceNotifier {
  const SilentTonPriceNotifier();

  @override
  Future<void> notifySourceFailure({
    required String reason,
    required TonPriceFallbackSource fallback,
  }) async {}

  @override
  Future<void> notifyUnavailable(String reason) async {}

  @override
  Future<void> notifyStorageFailure({
    required TonPriceStorageOperation operation,
    required String reason,
  }) async {}
}

class TonPriceAdminNotifier implements TonPriceNotifier {
  TonPriceAdminNotifier({
    required ReplyHandler reply,
    required Set<int> adminTelegramIds,
    required Duration cooldown,
    DateTime Function()? clock,
  }) : _reply = reply,
       _adminTelegramIds = Set.unmodifiable(adminTelegramIds),
       _cooldown = cooldown,
       _clock = clock ?? DateTime.now;

  final ReplyHandler _reply;
  final Set<int> _adminTelegramIds;
  final Duration _cooldown;
  final DateTime Function() _clock;
  final Map<String, DateTime> _lastSentAt = {};

  @override
  Future<void> notifySourceFailure({
    required String reason,
    required TonPriceFallbackSource fallback,
  }) {
    final fallbackText = switch (fallback) {
      TonPriceFallbackSource.database => 'последний свежий курс из SQLite',
      TonPriceFallbackSource.environment =>
        'резервный курс FRAGMENT_TON_PRICE_USD',
    };
    return _send(
      'source:${fallback.name}',
      TonPriceAdminText.sourceFailure(reason: reason, fallback: fallbackText),
    );
  }

  @override
  Future<void> notifyUnavailable(String reason) {
    return _send('unavailable', TonPriceAdminText.unavailable(reason));
  }

  @override
  Future<void> notifyStorageFailure({
    required TonPriceStorageOperation operation,
    required String reason,
  }) {
    final operationText = switch (operation) {
      TonPriceStorageOperation.read => 'чтение',
      TonPriceStorageOperation.write => 'запись',
    };
    return _send(
      'storage:${operation.name}',
      TonPriceAdminText.storageFailure(
        operation: operationText,
        reason: reason,
      ),
    );
  }

  Future<void> _send(String eventKey, String text) async {
    if (_adminTelegramIds.isEmpty) return;
    final now = _clock().toUtc();
    final lastSentAt = _lastSentAt[eventKey];
    final elapsed = lastSentAt == null ? null : now.difference(lastSentAt);
    if (elapsed != null && !elapsed.isNegative && elapsed < _cooldown) return;
    _lastSentAt[eventKey] = now;

    var delivered = false;
    for (final telegramId in _adminTelegramIds) {
      try {
        await _reply.sendText(ChatID(telegramId), text);
        delivered = true;
      } catch (error, stackTrace) {
        BotLog.error(
          'ton_price admin_notification_failed admin=$telegramId '
          'error=${error.runtimeType}',
        );
        if (BotLog.verbose) BotLog.debug(stackTrace.toString());
      }
    }
    if (!delivered && _lastSentAt[eventKey] == now) {
      _lastSentAt.remove(eventKey);
    }
  }
}
