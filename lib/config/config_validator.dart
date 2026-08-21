import 'package:pozzy_bot/config/config.dart';
import 'package:pozzy_bot/database/models/ton_amount.dart';
import 'package:televerse/televerse.dart';

class ConfigValidator {
  static void validateGiftPrice() {
    for (var giftIndex = 1; giftIndex <= 9; giftIndex++) {
      Config.giftPriceRub(giftIndex);
    }
  }

  static void validateTonPricing() {
    final baseUri = Uri.tryParse(Config.geckoTerminalApiBaseUrl);
    final isLoopback =
        baseUri?.host == 'localhost' ||
        baseUri?.host == '127.0.0.1' ||
        baseUri?.host == '::1';
    if (baseUri == null ||
        !baseUri.hasScheme ||
        baseUri.host.isEmpty ||
        (!isLoopback && baseUri.scheme != 'https')) {
      throw StateError('GECKOTERMINAL_API_BASE_URL must be a valid HTTPS URL');
    }
    if (Config.geckoTerminalTonNetwork.isEmpty) {
      throw StateError('GECKOTERMINAL_TON_NETWORK must not be empty');
    }
    if (Config.geckoTerminalTonTokenAddress.isEmpty) {
      throw StateError('GECKOTERMINAL_TON_TOKEN_ADDRESS must not be empty');
    }

    _requirePositive(
      Config.geckoTerminalTonPriceCacheSeconds,
      'GECKOTERMINAL_TON_PRICE_CACHE_SECONDS',
    );
    _requirePositive(
      Config.geckoTerminalApiTimeoutSeconds,
      'GECKOTERMINAL_API_TIMEOUT_SECONDS',
    );
    _requireInRange(
      Config.geckoTerminalRetryAttempts,
      minimum: 1,
      maximum: 5,
      key: 'GECKOTERMINAL_RETRY_ATTEMPTS',
    );
    _requirePositive(
      Config.geckoTerminalRetryBaseDelayMilliseconds,
      'GECKOTERMINAL_RETRY_BASE_DELAY_MS',
    );
    _requirePositive(
      Config.geckoTerminalFailureCooldownSeconds,
      'GECKOTERMINAL_FAILURE_COOLDOWN_SECONDS',
    );
    _requirePositive(
      Config.geckoTerminalStoredPriceMaximumAgeSeconds,
      'GECKOTERMINAL_STORED_PRICE_MAXIMUM_AGE_SECONDS',
    );
    _requirePositive(
      Config.fragmentTonPriceUsdMaximumAgeSeconds,
      'FRAGMENT_TON_PRICE_USD_MAXIMUM_AGE_SECONDS',
    );
    _requirePositive(
      Config.tonRateSessionTtlSeconds,
      'TON_RATE_SESSION_TTL_SECONDS',
    );
    _requirePositive(
      Config.tonPriceAdminNotificationCooldownSeconds,
      'TON_PRICE_ADMIN_NOTIFICATION_COOLDOWN_SECONDS',
    );

    final minimum = _requirePositiveDecimal(
      Config.geckoTerminalMinimumTonUsdRaw,
      'GECKOTERMINAL_MIN_TON_USD',
    );
    final maximum = _requirePositiveDecimal(
      Config.geckoTerminalMaximumTonUsdRaw,
      'GECKOTERMINAL_MAX_TON_USD',
    );
    if (minimum >= maximum) {
      throw StateError(
        'GECKOTERMINAL_MIN_TON_USD must be less than '
        'GECKOTERMINAL_MAX_TON_USD',
      );
    }
    _requirePositiveDecimal(
      Config.geckoTerminalMaximumChangePercentRaw,
      'GECKOTERMINAL_MAX_CHANGE_PERCENT',
    );
    _requirePercent(
      Config.fragmentTonMarkupPercentRaw,
      'FRAGMENT_TON_MARKUP_PERCENT',
    );

    final fallback = Config.fragmentTonPriceUsdRaw;
    final fallbackUpdatedAt = Config.fragmentTonPriceUsdUpdatedAtRaw;
    if (fallback.isEmpty && fallbackUpdatedAt.isNotEmpty) {
      throw StateError(
        'FRAGMENT_TON_PRICE_USD_UPDATED_AT requires FRAGMENT_TON_PRICE_USD',
      );
    }
    if (fallback.isNotEmpty) {
      final fallbackValue = _requirePositiveDecimal(
        fallback,
        'FRAGMENT_TON_PRICE_USD',
      );
      if (fallbackValue < minimum || fallbackValue > maximum) {
        throw StateError(
          'FRAGMENT_TON_PRICE_USD must be between the configured TON/USD bounds',
        );
      }
      final updatedAt = DateTime.tryParse(fallbackUpdatedAt);
      if (updatedAt == null) {
        throw StateError(
          'FRAGMENT_TON_PRICE_USD_UPDATED_AT must contain an ISO-8601 date',
        );
      }
    }
  }

  static void validateTonWallet() {
    final baseUri = Uri.tryParse(Config.tonApiBaseUrl);
    if (baseUri == null ||
        !baseUri.hasScheme ||
        baseUri.host.isEmpty ||
        baseUri.scheme != 'https') {
      throw StateError('TONAPI_BASE_URL must be a valid HTTPS URL');
    }
    _requirePositive(Config.tonApiTimeoutSeconds, 'TONAPI_TIMEOUT_SECONDS');
    _requirePositive(
      Config.tonApiMinRequestIntervalMilliseconds,
      'TONAPI_MIN_REQUEST_INTERVAL_MS',
    );
    _requirePositive(
      Config.tonWalletConfirmAttempts,
      'TON_WALLET_CONFIRM_ATTEMPTS',
    );
    _requirePositive(
      Config.tonWalletConfirmIntervalSeconds,
      'TON_WALLET_CONFIRM_INTERVAL_SECONDS',
    );
    _requirePositive(
      Config.tonWalletReconciliationIntervalSeconds,
      'TON_WALLET_RECONCILIATION_INTERVAL_SECONDS',
    );
    _requirePositive(
      Config.tonWalletReconciliationMinAgeSeconds,
      'TON_WALLET_RECONCILIATION_MIN_AGE_SECONDS',
    );
    final reserve = Config.tonWalletFeeReserveNanoRaw;
    if (reserve.isNotEmpty) {
      final nano = int.tryParse(reserve);
      if (nano == null || nano < 0) {
        throw StateError(
          'TON_WALLET_FEE_RESERVE_NANO must contain a non-negative integer',
        );
      }
      TonAmount.fromNano(nano);
    }
  }

  static void validateTonAddress() {
    final network = Config.tonApiTestnetRaw;
    if (network != 'true' && network != 'false') {
      throw StateError('TONAPI_TESTNET must be true or false');
    }
  }

  static Future<Bot<Context>> validateBotToken() async {
    try {
      final bot = Bot<Context>(Config.botToken);
      await bot.initialize();
      print('this token is valid!');
      return bot;
    } catch (e) {
      print('Telegram token validation failed: $e');
      throw StateError('ERROR: Token not found');
    }
  }

  static void _requirePositive(int value, String key) {
    if (value <= 0) throw StateError('$key must be greater than zero');
  }

  static void _requireInRange(
    int value, {
    required int minimum,
    required int maximum,
    required String key,
  }) {
    if (value < minimum || value > maximum) {
      throw StateError('$key must be between $minimum and $maximum');
    }
  }

  static double _requirePositiveDecimal(String raw, String key) {
    final value = double.tryParse(raw);
    if (value == null || !value.isFinite || value <= 0) {
      throw StateError('$key must contain a positive decimal');
    }
    return value;
  }

  static double _requirePercent(String raw, String key) {
    final value = double.tryParse(raw);
    if (value == null || !value.isFinite || value < 0 || value > 100) {
      throw StateError('$key must be between 0 and 100');
    }
    return value;
  }
}
