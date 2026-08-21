import 'dart:io';

import 'package:dotenv/dotenv.dart';
import 'package:pozzy_bot/database/models/rub_amount.dart';

final env = DotEnv(quiet: true).._loadEnv();

extension on DotEnv {
  void _loadEnv() {
    final path = _resolveEnvFilePath();
    if (path != null) {
      load([path]);
      return;
    }
    load();
  }
}

String? _resolveEnvFilePath() {
  const envFileName = '.env';

  final inCwd = File(envFileName);
  if (inCwd.existsSync()) return inCwd.path;

  final nested = File('pozzy_bot${Platform.pathSeparator}$envFileName');
  if (nested.existsSync()) return nested.path;

  var dir = Directory.current;
  while (true) {
    final pubspec = File('${dir.path}${Platform.pathSeparator}pubspec.yaml');
    if (pubspec.existsSync()) {
      final besidePubspec = File(
        '${dir.path}${Platform.pathSeparator}$envFileName',
      );
      return besidePubspec.existsSync() ? besidePubspec.path : null;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  return null;
}

class Config {
  static String? get envFilePath => _resolveEnvFilePath();

  static final Map<String, String> _menuPhotoFileIdOverrides = {};
  static final Map<String, String> _menuPhotoSourceOverrides = {};

  static String get botToken => env['BOT_TOKEN'] ?? '';

  static String get dbPath => env['DB_PATH'] ?? 'data/pozzy.db';

  static String get botUsername => env['BOT_USERNAME']?.trim() ?? '';

  static double get referralPurchasePercent =>
      double.tryParse(env['REFERRAL_PURCHASE_PERCENT'] ?? '') ?? 0.15;

  static String get referralPurchaseFractionRaw =>
      env['REFERRAL_PURCHASE_PERCENT']?.trim() ?? '0.15';

  static String get userbotApiBaseUrl =>
      env['USERBOT_API_BASE_URL']?.trim() ?? 'http://127.0.0.1:8090';

  static String get userbotApiSecret => env['USERBOT_API_SECRET']?.trim() ?? '';

  static RubAmount giftPriceRub(int giftIndex) {
    if (giftIndex < 1 || giftIndex > 9) {
      throw RangeError.range(giftIndex, 1, 9, 'giftIndex');
    }

    final individualKey = 'GIFT_${giftIndex}_PRICE_RUB';
    final individualRaw = env[individualKey]?.trim() ?? '';
    if (individualRaw.isNotEmpty) {
      return _parseGiftPriceRub(individualRaw, individualKey);
    }

    return _parseGiftPriceRub(
      env['GIFT_PRICE_RUB']?.trim() ?? '',
      'GIFT_PRICE_RUB',
    );
  }

  static RubAmount _parseGiftPriceRub(String raw, String key) {
    if (!RegExp(r'^\d+(?:\.\d{1,2})?$').hasMatch(raw)) {
      throw StateError(
        '$key must be a RUB amount with no more than 2 decimals',
      );
    }
    final value = RubAmount.parse(raw);
    if (value.isZero) {
      throw StateError('$key must be greater than zero');
    }
    return value;
  }

  static double get giftDefaultPriceUsd =>
      double.tryParse(env['GIFT_PRICE_USD'] ?? '') ?? 0.5;

  static double giftPriceUsd(int giftIndex) {
    final individual = double.tryParse(
      env['GIFT_${giftIndex}_PRICE_USD'] ?? '',
    );
    return individual ?? giftDefaultPriceUsd;
  }

  static String get fragmentApiBaseUrl =>
      env['FRAGMENT_API_BASE_URL']?.trim() ??
      'https://fragment-api.arijitiyan.cc';

  static List<String> get fragmentWalletSeedWords {
    final raw = env['FRAGMENT_WALLET_SEED']?.trim() ?? '';
    if (raw.isEmpty) return const [];
    return raw
        .split(RegExp(r'[,;\s]+'))
        .map((word) => word.trim())
        .where((word) => word.isNotEmpty)
        .toList(growable: false);
  }

  static int get fragmentApiTimeoutSeconds =>
      int.tryParse(env['FRAGMENT_API_TIMEOUT_SECONDS'] ?? '') ?? 120;

  static int get fragmentPendingReviewAgeSeconds =>
      int.tryParse(env['FRAGMENT_PENDING_REVIEW_AGE_SECONDS'] ?? '') ?? 30;

  static String get tonApiKey => env['TONAPI_API_KEY']?.trim() ?? '';

  static String get tonApiBaseUrl =>
      env['TONAPI_BASE_URL']?.trim() ?? 'https://tonapi.io';

  static String get tonApiTestnetRaw =>
      (env['TONAPI_TESTNET'] ?? 'false').trim().toLowerCase();

  static bool get tonApiTestnet => tonApiTestnetRaw == 'true';

  static int get tonApiTimeoutSeconds =>
      int.tryParse(env['TONAPI_TIMEOUT_SECONDS'] ?? '') ?? 30;

  static int get tonApiMinRequestIntervalMilliseconds =>
      int.tryParse(env['TONAPI_MIN_REQUEST_INTERVAL_MS'] ?? '') ?? 1000;

  static String get tonWalletFeeReserveNanoRaw =>
      env['TON_WALLET_FEE_RESERVE_NANO']?.trim() ?? '';

  static int get tonWalletConfirmAttempts =>
      int.tryParse(env['TON_WALLET_CONFIRM_ATTEMPTS'] ?? '') ?? 20;

  static int get tonWalletConfirmIntervalSeconds =>
      int.tryParse(env['TON_WALLET_CONFIRM_INTERVAL_SECONDS'] ?? '') ?? 2;

  static int get tonWalletReconciliationIntervalSeconds =>
      int.tryParse(env['TON_WALLET_RECONCILIATION_INTERVAL_SECONDS'] ?? '') ??
      60;

  static int get tonWalletReconciliationMinAgeSeconds =>
      int.tryParse(env['TON_WALLET_RECONCILIATION_MIN_AGE_SECONDS'] ?? '') ??
      30;

  static String get fragmentStarsApiBaseUrl {
    final value = env['FRAGMENT_STARS_API_BASE_URL']?.trim() ?? '';
    if (value.isEmpty) {
      throw StateError('FRAGMENT_STARS_API_BASE_URL is not configured');
    }
    return value;
  }

  static int get fragmentStarsApiTimeoutSeconds =>
      int.tryParse(env['FRAGMENT_STARS_API_TIMEOUT_SECONDS'] ?? '') ?? 30;

  static int get fragmentStarsPriceCacheSeconds =>
      int.tryParse(env['FRAGMENT_STARS_PRICE_CACHE_SECONDS'] ?? '') ?? 60;

  static String get fragmentStarsMarkupPercentRaw =>
      env['FRAGMENT_STARS_MARKUP_PERCENT']?.trim() ?? '0';

  static String get fragmentTonMarkupPercentRaw =>
      env['FRAGMENT_TON_MARKUP_PERCENT']?.trim() ?? '0';

  static String get fragmentStarPriceUsdRaw =>
      env['FRAGMENT_STAR_PRICE_USD']?.trim() ?? '';

  static String get fragmentTonPriceUsdRaw =>
      env['FRAGMENT_TON_PRICE_USD']?.trim() ?? '';

  static String get geckoTerminalApiBaseUrl =>
      env['GECKOTERMINAL_API_BASE_URL']?.trim() ??
      'https://api.geckoterminal.com/api/v2';

  static String get geckoTerminalTonNetwork =>
      env['GECKOTERMINAL_TON_NETWORK']?.trim() ?? 'ton';

  static String get geckoTerminalTonTokenAddress =>
      env['GECKOTERMINAL_TON_TOKEN_ADDRESS']?.trim() ??
      'EQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAM9c';

  static int get geckoTerminalTonPriceCacheSeconds =>
      int.tryParse(env['GECKOTERMINAL_TON_PRICE_CACHE_SECONDS'] ?? '') ?? 60;

  static int get geckoTerminalApiTimeoutSeconds =>
      int.tryParse(env['GECKOTERMINAL_API_TIMEOUT_SECONDS'] ?? '') ?? 15;

  static int get geckoTerminalRetryAttempts =>
      int.tryParse(env['GECKOTERMINAL_RETRY_ATTEMPTS'] ?? '') ?? 3;

  static int get geckoTerminalRetryBaseDelayMilliseconds =>
      int.tryParse(env['GECKOTERMINAL_RETRY_BASE_DELAY_MS'] ?? '') ?? 500;

  static int get geckoTerminalFailureCooldownSeconds =>
      int.tryParse(env['GECKOTERMINAL_FAILURE_COOLDOWN_SECONDS'] ?? '') ?? 30;

  static int get geckoTerminalStoredPriceMaximumAgeSeconds =>
      int.tryParse(
        env['GECKOTERMINAL_STORED_PRICE_MAXIMUM_AGE_SECONDS'] ?? '',
      ) ??
      7200;

  static String get geckoTerminalMinimumTonUsdRaw =>
      env['GECKOTERMINAL_MIN_TON_USD']?.trim() ?? '0.1';

  static String get geckoTerminalMaximumTonUsdRaw =>
      env['GECKOTERMINAL_MAX_TON_USD']?.trim() ?? '100';

  static String get geckoTerminalMaximumChangePercentRaw =>
      env['GECKOTERMINAL_MAX_CHANGE_PERCENT']?.trim() ?? '30';

  static String get fragmentTonPriceUsdUpdatedAtRaw =>
      env['FRAGMENT_TON_PRICE_USD_UPDATED_AT']?.trim() ?? '';

  static int get fragmentTonPriceUsdMaximumAgeSeconds =>
      int.tryParse(env['FRAGMENT_TON_PRICE_USD_MAXIMUM_AGE_SECONDS'] ?? '') ??
      86400;

  static int get tonRateSessionTtlSeconds =>
      int.tryParse(env['TON_RATE_SESSION_TTL_SECONDS'] ?? '') ?? 600;

  static int get tonPriceAdminNotificationCooldownSeconds =>
      int.tryParse(
        env['TON_PRICE_ADMIN_NOTIFICATION_COOLDOWN_SECONDS'] ?? '',
      ) ??
      300;

  static String get twelveDataApiKey =>
      env['TWELVE_DATA_API_KEY']?.trim() ?? '';

  static String get twelveDataApiBaseUrl =>
      env['TWELVE_DATA_API_BASE_URL']?.trim() ?? 'https://api.twelvedata.com';

  static String get exchangeRateApiKey =>
      env['EXCHANGE_RATE_API_KEY']?.trim() ?? '';

  static String get exchangeRateApiBaseUrl =>
      env['EXCHANGE_RATE_API_BASE_URL']?.trim() ??
      'https://v6.exchangerate-api.com/v6';

  static int get exchangeRateApiTimeoutSeconds =>
      int.tryParse(env['EXCHANGE_RATE_API_TIMEOUT_SECONDS'] ?? '') ?? 15;

  static int get exchangeRateRefreshSeconds =>
      int.tryParse(env['EXCHANGE_RATE_REFRESH_SECONDS'] ?? '') ?? 300;

  static int get exchangeRatePrimaryMaximumAgeSeconds =>
      int.tryParse(env['EXCHANGE_RATE_PRIMARY_MAXIMUM_AGE_SECONDS'] ?? '') ??
      7200;

  static int get exchangeRatePrimarySourceMaximumAgeSeconds =>
      int.tryParse(
        env['EXCHANGE_RATE_PRIMARY_SOURCE_MAXIMUM_AGE_SECONDS'] ?? '',
      ) ??
      7200;

  static int get exchangeRateFallbackRefreshSeconds =>
      int.tryParse(env['EXCHANGE_RATE_FALLBACK_REFRESH_SECONDS'] ?? '') ??
      86400;

  static int get exchangeRateFallbackRetrySeconds =>
      int.tryParse(env['EXCHANGE_RATE_FALLBACK_RETRY_SECONDS'] ?? '') ?? 3600;

  static int get exchangeRateFallbackMaximumAgeSeconds =>
      int.tryParse(env['EXCHANGE_RATE_FALLBACK_MAXIMUM_AGE_SECONDS'] ?? '') ??
      93600;

  static int get exchangeRateAbsoluteMaximumAgeSeconds =>
      int.tryParse(env['EXCHANGE_RATE_ABSOLUTE_MAXIMUM_AGE_SECONDS'] ?? '') ??
      259200;

  static int get exchangeRateAllowedClockSkewSeconds =>
      int.tryParse(env['EXCHANGE_RATE_ALLOWED_CLOCK_SKEW_SECONDS'] ?? '') ??
      300;

  static String get exchangeRateMinimumRaw =>
      env['EXCHANGE_RATE_MIN_USD_RUB']?.trim() ?? '10';

  static String get exchangeRateMaximumRaw =>
      env['EXCHANGE_RATE_MAX_USD_RUB']?.trim() ?? '500';

  static String get exchangeRateMaximumChangePercentRaw =>
      env['EXCHANGE_RATE_MAX_CHANGE_PERCENT']?.trim() ?? '20';

  static String get exchangeRateMaximumProviderDifferencePercentRaw =>
      env['EXCHANGE_RATE_MAX_PROVIDER_DIFFERENCE_PERCENT']?.trim() ?? '10';

  static int get exchangeRateMenuPriceTtlSeconds =>
      int.tryParse(env['EXCHANGE_RATE_MENU_PRICE_TTL_SECONDS'] ?? '') ?? 600;

  static String fragmentPremiumPriceUsdRaw(int months) =>
      env['FRAGMENT_PREMIUM_${months}M_PRICE_USD']?.trim() ?? '';

  static String get initialAdminTelegramIdsRaw =>
      env['ADMIN_IDS']?.trim() ?? '';

  static String get adminMaximumTopUpUsdRaw =>
      env['ADMIN_MAX_TOP_UP_USD']?.trim() ?? '10000';

  static int get adminFlowTtlSeconds =>
      int.tryParse(env['ADMIN_FLOW_TTL_SECONDS'] ?? '') ?? 600;

  static int get adminBroadcastDelayMilliseconds =>
      int.tryParse(env['ADMIN_BROADCAST_DELAY_MS'] ?? '') ?? 40;

  static bool get botVerboseLogging =>
      (env['TOPUP_VERBOSE_LOG'] ?? 'false').trim().toLowerCase() == 'true';

  static void applyMenuPhotoFileId(String envKey, String fileId) {
    _menuPhotoFileIdOverrides[envKey] = fileId;
  }

  static void applyMenuPhotoSource(String envKey, String sourceFileName) {
    _menuPhotoSourceOverrides[envKey] = sourceFileName;
  }

  static void clearMenuPhotoFileId(String envKey) {
    _menuPhotoFileIdOverrides[envKey] = '';
  }

  static void clearMenuPhotoSource(String envKey) {
    _menuPhotoSourceOverrides[envKey] = '';
  }

  static Set<int> get initialAdminTelegramIds {
    final raw = initialAdminTelegramIdsRaw;
    if (raw.isEmpty) return {};
    final ids = <int>{};
    for (final part in raw.split(RegExp(r'[,;\s]+'))) {
      final piece = part.trim();
      if (piece.isEmpty) continue;
      final id = int.tryParse(piece);
      if (id != null && id > 0) ids.add(id);
    }
    return ids;
  }

  static String? menuPhotoFileId(String envKey) {
    if (_menuPhotoFileIdOverrides.containsKey(envKey)) {
      final override = _menuPhotoFileIdOverrides[envKey]!;
      return override.isEmpty ? null : override;
    }
    final raw = env[envKey]?.trim();
    if (raw == null || raw.isEmpty) return null;
    return raw;
  }

  static String? menuPhotoSource(String envKey) {
    if (_menuPhotoSourceOverrides.containsKey(envKey)) {
      final override = _menuPhotoSourceOverrides[envKey]!;
      return override.isEmpty ? null : override;
    }
    final raw = env[envKey]?.trim();
    if (raw == null || raw.isEmpty) return null;
    return raw;
  }
}
