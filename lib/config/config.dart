import 'dart:io';
import 'package:dotenv/dotenv.dart';

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

  static String get fragmentStarsApiBaseUrl =>
      env['FRAGMENT_STARS_API_BASE_URL']?.trim() ??
      'https://fragment-api.ydns.eu:8443';

  static int get fragmentStarsApiTimeoutSeconds =>
      int.tryParse(env['FRAGMENT_STARS_API_TIMEOUT_SECONDS'] ?? '') ?? 30;

  static int get fragmentStarsPriceCacheSeconds =>
      int.tryParse(env['FRAGMENT_STARS_PRICE_CACHE_SECONDS'] ?? '') ?? 60;

  static String get fragmentStarsMarkupPercentRaw =>
      env['FRAGMENT_STARS_MARKUP_PERCENT']?.trim() ?? '0';

  static String get fragmentStarPriceUsdRaw =>
      env['FRAGMENT_STAR_PRICE_USD']?.trim() ?? '';

  static String get fragmentTonPriceUsdRaw =>
      env['FRAGMENT_TON_PRICE_USD']?.trim() ?? '';

  static String fragmentPremiumPriceUsdRaw(int months) =>
      env['FRAGMENT_PREMIUM_${months}M_PRICE_USD']?.trim() ?? '';

  static String get initialAdminTelegramIdsRaw =>
      env['ADMIN_IDS']?.trim() ?? '';

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
    for (final part in raw.split(';')) {
      final piece = part.trim();
      if (piece.isEmpty) continue;
      ids.add(int.parse(piece));
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
