import 'package:pozzy_bot/config/config.dart';
import 'package:pozzy_bot/database/models/fragment_purchase_type.dart';
import 'package:pozzy_bot/database/models/ton_amount.dart';
import 'package:pozzy_bot/database/models/usd_amount.dart';
import 'package:pozzy_bot/services/fragment/fragment_api_exception.dart';
import 'package:pozzy_bot/services/fragment_stars_api/fragment_stars_price_client.dart';
import 'package:pozzy_bot/services/fragment_stars_api/fragment_stars_price_exception.dart';
import 'package:pozzy_bot/services/fragment_stars_api/fragment_stars_price_gateway.dart';
import 'package:pozzy_bot/services/fragment_stars_api/fragment_star_price_store.dart';
import 'package:pozzy_bot/services/geckoterminal/geckoterminal_client.dart';
import 'package:pozzy_bot/services/geckoterminal/geckoterminal_exception.dart';
import 'package:pozzy_bot/services/geckoterminal/geckoterminal_ton_price_gateway.dart';
import 'package:pozzy_bot/services/geckoterminal/ton_price_notifier.dart';
import 'package:pozzy_bot/services/geckoterminal/ton_price_store.dart';
import 'package:pozzy_bot/utils/bot_log.dart';

class FragmentPriceQuote {
  const FragmentPriceQuote({
    required this.purchaseType,
    required this.quantityUnits,
    required this.price,
    this.unitPrice,
    this.basePrice,
    this.markupAmount,
  });

  final FragmentPurchaseType purchaseType;
  final int quantityUnits;
  final UsdAmount price;
  final UsdAmount? unitPrice;
  final UsdAmount? basePrice;
  final UsdAmount? markupAmount;
}

class FragmentPricingService {
  FragmentPricingService({
    String? starPriceUsd,
    String? starsMarkupPercent,
    String? tonPriceUsd,
    String? tonMarkupPercent,
    Map<int, String>? premiumPricesUsd,
    FragmentStarsPriceGateway? starsPriceGateway,
    FragmentStarPriceStore? starsPriceStore,
    String? fallbackStarPriceUsd,
    GeckoTerminalTonPriceGateway? tonPriceGateway,
    TonPriceStore? tonPriceStore,
    TonPriceNotifier? tonPriceNotifier,
    String? fallbackTonPriceUsd,
    String? fallbackTonPriceUsdUpdatedAt,
    Duration? storedTonPriceMaximumAge,
    Duration? fallbackTonPriceMaximumAge,
    String? minimumTonPriceUsd,
    String? maximumTonPriceUsd,
    String? maximumTonPriceChangePercent,
    DateTime Function()? clock,
  }) : _starPriceUsd = starPriceUsd,
       _starsMarkupPercent = starsMarkupPercent,
       _tonPriceUsd = tonPriceUsd,
       _tonMarkupPercent = tonMarkupPercent,
       _premiumPricesUsd = premiumPricesUsd,
       _starsPriceStore = starsPriceStore,
       _fallbackStarPriceUsd = fallbackStarPriceUsd,
       _fallbackTonPriceUsd = fallbackTonPriceUsd,
       _fallbackTonPriceUsdUpdatedAt = fallbackTonPriceUsdUpdatedAt,
       _tonPriceStore = tonPriceStore,
       _tonPriceNotifier = tonPriceNotifier ?? const SilentTonPriceNotifier(),
       _storedTonPriceMaximumAge =
           storedTonPriceMaximumAge ??
           Duration(seconds: Config.geckoTerminalStoredPriceMaximumAgeSeconds),
       _fallbackTonPriceMaximumAge =
           fallbackTonPriceMaximumAge ??
           Duration(seconds: Config.fragmentTonPriceUsdMaximumAgeSeconds),
       _minimumTonPriceUsd = minimumTonPriceUsd,
       _maximumTonPriceUsd = maximumTonPriceUsd,
       _maximumTonPriceChangePercent = maximumTonPriceChangePercent,
       _clock = clock ?? DateTime.now,
       _starsPriceGateway =
           starsPriceGateway ??
           FragmentStarsPriceClient(
             baseUri: Uri.parse(Config.fragmentStarsApiBaseUrl),
             timeout: Duration(seconds: Config.fragmentStarsApiTimeoutSeconds),
             cacheTtl: Duration(seconds: Config.fragmentStarsPriceCacheSeconds),
           ),
       _tonPriceGateway =
           tonPriceGateway ??
           GeckoTerminalClient(
             baseUri: Uri.parse(Config.geckoTerminalApiBaseUrl),
             network: Config.geckoTerminalTonNetwork,
             tonTokenAddress: Config.geckoTerminalTonTokenAddress,
             timeout: Duration(seconds: Config.geckoTerminalApiTimeoutSeconds),
             cacheTtl: Duration(
               seconds: Config.geckoTerminalTonPriceCacheSeconds,
             ),
             retryAttempts: Config.geckoTerminalRetryAttempts,
             retryBaseDelay: Duration(
               milliseconds: Config.geckoTerminalRetryBaseDelayMilliseconds,
             ),
             failureCooldown: Duration(
               seconds: Config.geckoTerminalFailureCooldownSeconds,
             ),
           );

  final String? _starPriceUsd;
  final String? _starsMarkupPercent;
  final String? _tonPriceUsd;
  final String? _tonMarkupPercent;
  final Map<int, String>? _premiumPricesUsd;
  final FragmentStarsPriceGateway _starsPriceGateway;
  final FragmentStarPriceStore? _starsPriceStore;
  final String? _fallbackStarPriceUsd;
  final GeckoTerminalTonPriceGateway _tonPriceGateway;
  final TonPriceStore? _tonPriceStore;
  final TonPriceNotifier _tonPriceNotifier;
  final String? _fallbackTonPriceUsd;
  final String? _fallbackTonPriceUsdUpdatedAt;
  final Duration _storedTonPriceMaximumAge;
  final Duration _fallbackTonPriceMaximumAge;
  final String? _minimumTonPriceUsd;
  final String? _maximumTonPriceUsd;
  final String? _maximumTonPriceChangePercent;
  final DateTime Function() _clock;
  Future<UsdAmount>? _inFlightStarUnitPrice;
  Future<UsdAmount>? _inFlightTonUsdRate;

  Future<UsdAmount> getStarUnitPrice() async {
    final override = _starPriceUsd;
    if (override != null) {
      return _configuredUsd(override, 'starPriceUsd');
    }

    final activeRequest = _inFlightStarUnitPrice;
    if (activeRequest != null) return activeRequest;

    final request = _resolveStarUnitPrice();
    _inFlightStarUnitPrice = request;
    try {
      return await request;
    } finally {
      if (identical(_inFlightStarUnitPrice, request)) {
        _inFlightStarUnitPrice = null;
      }
    }
  }

  Future<UsdAmount> _resolveStarUnitPrice() async {
    try {
      final prices = await _starsPriceGateway.getPrices();
      _saveServerPrice(prices.usdPerStar, prices.cachedAt ?? _clock().toUtc());
      return prices.usdPerStar;
    } on FragmentStarsPriceException catch (error) {
      final stored = _loadStoredPrice();
      if (stored != null) {
        BotLog.error(
          'fragment_stars_price_failed fallback=database '
          'status=${error.statusCode ?? 'none'} network=${error.isNetworkError} '
          'stored_at=${stored.fetchedAt.toIso8601String()}',
        );
        return stored.usdPerStar;
      }

      final fallback = _fallbackStarPriceUsd ?? Config.fragmentStarPriceUsdRaw;
      if (fallback.isNotEmpty) {
        BotLog.error(
          'fragment_stars_price_failed fallback=FRAGMENT_STAR_PRICE_USD '
          'status=${error.statusCode ?? 'none'} network=${error.isNetworkError}',
        );
        return _configuredUsd(fallback, 'FRAGMENT_STAR_PRICE_USD');
      }
      throw FragmentApiException(
        kind: _priceErrorKind(error),
        message: error.message,
        statusCode: error.statusCode,
      );
    }
  }

  void _saveServerPrice(UsdAmount price, DateTime fetchedAt) {
    final store = _starsPriceStore;
    if (store == null) return;
    try {
      store.save(usdPerStar: price, fetchedAt: fetchedAt);
    } catch (error) {
      BotLog.error(
        'fragment_star_price_cache write_failed error=${error.runtimeType}',
      );
    }
  }

  StoredFragmentStarPrice? _loadStoredPrice() {
    final store = _starsPriceStore;
    if (store == null) return null;
    try {
      return store.findLast();
    } catch (error) {
      BotLog.error(
        'fragment_star_price_cache read_failed error=${error.runtimeType}',
      );
      return null;
    }
  }

  Future<FragmentPriceQuote> quoteStars(int amount) async {
    if (amount < 50 || amount > 1000000) {
      throw const FragmentApiException(
        kind: FragmentApiErrorKind.configuration,
        message: 'Stars amount must be between 50 and 1000000',
      );
    }
    final unitPrice = await getStarUnitPrice();
    final basePrice = unitPrice.multiply(amount);
    final markupPercent =
        _starsMarkupPercent ?? Config.fragmentStarsMarkupPercentRaw;
    final markupAmount = _markup(
      basePrice,
      markupPercent,
      'FRAGMENT_STARS_MARKUP_PERCENT',
    );
    return FragmentPriceQuote(
      purchaseType: FragmentPurchaseType.stars,
      quantityUnits: amount,
      price: basePrice.add(markupAmount),
      unitPrice: unitPrice,
      basePrice: basePrice,
      markupAmount: markupAmount,
    );
  }

  FragmentPriceQuote quotePremium(int months) {
    if (months != 3 && months != 6 && months != 12) {
      throw const FragmentApiException(
        kind: FragmentApiErrorKind.configuration,
        message: 'Premium duration must be 3, 6, or 12 months',
      );
    }
    final raw =
        _premiumPricesUsd?[months] ?? Config.fragmentPremiumPriceUsdRaw(months);
    return FragmentPriceQuote(
      purchaseType: FragmentPurchaseType.premium,
      quantityUnits: months,
      price: _configuredUsd(raw, 'FRAGMENT_PREMIUM_${months}M_PRICE_USD'),
    );
  }

  Future<UsdAmount> getTonUsdRate() async {
    final override = _tonPriceUsd;
    if (override != null) {
      return _configuredUsd(override, 'tonPriceUsd');
    }

    final activeRequest = _inFlightTonUsdRate;
    if (activeRequest != null) return activeRequest;

    final request = _resolveTonUsdRate();
    _inFlightTonUsdRate = request;
    try {
      return await request;
    } finally {
      if (identical(_inFlightTonUsdRate, request)) {
        _inFlightTonUsdRate = null;
      }
    }
  }

  Future<UsdAmount> getTonUsdRateWithMarkup() async {
    final baseRate = await getTonUsdRate();
    final markupPercent =
        _tonMarkupPercent ?? Config.fragmentTonMarkupPercentRaw;
    return baseRate.add(
      _markup(baseRate, markupPercent, 'FRAGMENT_TON_MARKUP_PERCENT'),
    );
  }

  Future<UsdAmount> _resolveTonUsdRate() async {
    try {
      final liveRate = await _tonPriceGateway.getTonUsdPrice();
      final stored = await _loadStoredTonPrice();
      _validateTonPrice(liveRate, previous: stored?.usdPerTon);
      await _saveTonPrice(liveRate);
      return liveRate;
    } on GeckoTerminalException catch (error) {
      final stored = await _loadStoredTonPrice();
      if (stored != null) {
        BotLog.error(
          'ton_usd_rate_geckoterminal_failed fallback=database '
          'status=${error.statusCode ?? 'none'} '
          'network=${error.isNetworkError} '
          'stored_at=${stored.fetchedAt.toIso8601String()}',
        );
        await _notifySourceFailure(error, TonPriceFallbackSource.database);
        return stored.usdPerTon;
      }
      final fallback = _fallbackTonPriceUsd ?? Config.fragmentTonPriceUsdRaw;
      final fallbackUpdatedAt =
          _fallbackTonPriceUsdUpdatedAt ??
          Config.fragmentTonPriceUsdUpdatedAtRaw;
      if (fallback.isNotEmpty && _isFreshFallback(fallbackUpdatedAt)) {
        BotLog.error(
          'ton_usd_rate_geckoterminal_failed '
          'fallback=FRAGMENT_TON_PRICE_USD '
          'status=${error.statusCode ?? 'none'} '
          'network=${error.isNetworkError}',
        );
        final fallbackRate = _configuredUsd(fallback, 'FRAGMENT_TON_PRICE_USD');
        _validateTonPrice(fallbackRate);
        await _notifySourceFailure(error, TonPriceFallbackSource.environment);
        return fallbackRate;
      }
      await _safeNotify(
        () => _tonPriceNotifier.notifyUnavailable(_tonPriceErrorReason(error)),
      );
      throw FragmentApiException(
        kind: _tonPriceErrorKind(error),
        message: error.message,
        statusCode: error.statusCode,
      );
    }
  }

  Future<FragmentPriceQuote> quoteTon(TonAmount amount) async {
    if (amount.isZero) {
      throw const FragmentApiException(
        kind: FragmentApiErrorKind.configuration,
        message: 'TON amount must be greater than zero',
      );
    }
    final perTon = await getTonUsdRateWithMarkup();
    return quoteTonAtRate(amount, perTon);
  }

  FragmentPriceQuote quoteTonAtRate(TonAmount amount, UsdAmount perTon) {
    if (amount.isZero || perTon.isZero) {
      throw const FragmentApiException(
        kind: FragmentApiErrorKind.configuration,
        message: 'TON amount and TON/USD rate must be greater than zero',
      );
    }
    return FragmentPriceQuote(
      purchaseType: FragmentPurchaseType.ton,
      quantityUnits: amount.nano,
      price: perTon.multiplyRatio(amount.nano, TonAmount.nanoPerTon),
      unitPrice: perTon,
    );
  }

  Future<void> _saveTonPrice(UsdAmount rate) async {
    final store = _tonPriceStore;
    if (store == null) return;
    try {
      store.save(usdPerTon: rate, fetchedAt: _clock().toUtc());
    } catch (error) {
      BotLog.error(
        'ton_usd_price_cache write_failed error=${error.runtimeType}',
      );
      await _safeNotify(
        () => _tonPriceNotifier.notifyStorageFailure(
          operation: TonPriceStorageOperation.write,
          reason: error.runtimeType.toString(),
        ),
      );
    }
  }

  Future<StoredTonPrice?> _loadStoredTonPrice() async {
    final store = _tonPriceStore;
    if (store == null) return null;
    try {
      final stored = store.findLast();
      if (stored == null) return null;
      final age = _clock().toUtc().difference(stored.fetchedAt);
      if (age.isNegative || age > _storedTonPriceMaximumAge) {
        return null;
      }
      return stored;
    } catch (error) {
      BotLog.error(
        'ton_usd_price_cache read_failed error=${error.runtimeType}',
      );
      await _safeNotify(
        () => _tonPriceNotifier.notifyStorageFailure(
          operation: TonPriceStorageOperation.read,
          reason: error.runtimeType.toString(),
        ),
      );
      return null;
    }
  }

  Future<void> _notifySourceFailure(
    GeckoTerminalException error,
    TonPriceFallbackSource fallback,
  ) {
    return _safeNotify(
      () => _tonPriceNotifier.notifySourceFailure(
        reason: _tonPriceErrorReason(error),
        fallback: fallback,
      ),
    );
  }

  Future<void> _safeNotify(Future<void> Function() notify) async {
    try {
      await notify();
    } catch (error) {
      BotLog.error('ton_price notification_failed error=${error.runtimeType}');
    }
  }

  bool _isFreshFallback(String updatedAtRaw) {
    final updatedAt = DateTime.tryParse(updatedAtRaw)?.toUtc();
    if (updatedAt == null) return false;
    final age = _clock().toUtc().difference(updatedAt);
    return !age.isNegative && age <= _fallbackTonPriceMaximumAge;
  }

  void _validateTonPrice(UsdAmount rate, {UsdAmount? previous}) {
    final minimum = _configuredUsd(
      _minimumTonPriceUsd ?? Config.geckoTerminalMinimumTonUsdRaw,
      'GECKOTERMINAL_MIN_TON_USD',
    );
    final maximum = _configuredUsd(
      _maximumTonPriceUsd ?? Config.geckoTerminalMaximumTonUsdRaw,
      'GECKOTERMINAL_MAX_TON_USD',
    );
    if (rate.compareTo(minimum) < 0 || rate.compareTo(maximum) > 0) {
      throw const GeckoTerminalException(
        'TON/USD price is outside the configured range',
      );
    }
    if (previous == null) return;

    final rawPercent =
        _maximumTonPriceChangePercent ??
        Config.geckoTerminalMaximumChangePercentRaw;
    final maximumChange = double.tryParse(rawPercent);
    if (maximumChange == null ||
        !maximumChange.isFinite ||
        maximumChange <= 0) {
      throw const GeckoTerminalException(
        'Maximum TON/USD price change is invalid',
      );
    }
    final difference = (rate.micros - previous.micros).abs();
    final changePercent = difference * 100 / previous.micros;
    if (changePercent > maximumChange) {
      throw const GeckoTerminalException(
        'TON/USD price changed beyond the configured limit',
      );
    }
  }

  UsdAmount _configuredUsd(String raw, String key) {
    if (raw.trim().isEmpty) {
      throw FragmentApiException(
        kind: FragmentApiErrorKind.configuration,
        message: '$key is not configured',
      );
    }
    try {
      final amount = UsdAmount.parse(raw);
      if (amount.isZero) throw const FormatException('Zero price');
      return amount;
    } on FormatException {
      throw FragmentApiException(
        kind: FragmentApiErrorKind.configuration,
        message: '$key must contain a positive USD decimal',
      );
    }
  }

  UsdAmount _markup(UsdAmount basePrice, String rawPercent, String key) {
    try {
      return basePrice.percentage(rawPercent);
    } on FormatException {
      throw FragmentApiException(
        kind: FragmentApiErrorKind.configuration,
        message: '$key must be a non-negative number',
      );
    }
  }
}

FragmentApiErrorKind _priceErrorKind(FragmentStarsPriceException error) {
  if (error.isNetworkError) return FragmentApiErrorKind.network;
  final status = error.statusCode;
  if (status != null && status >= 500) return FragmentApiErrorKind.httpServer;
  if (status != null) return FragmentApiErrorKind.httpClient;
  return FragmentApiErrorKind.malformedResponse;
}

FragmentApiErrorKind _tonPriceErrorKind(GeckoTerminalException error) {
  if (error.isNetworkError) return FragmentApiErrorKind.network;
  final status = error.statusCode;
  if (status != null && status >= 500) return FragmentApiErrorKind.httpServer;
  if (status != null) return FragmentApiErrorKind.httpClient;
  return FragmentApiErrorKind.malformedResponse;
}

String _tonPriceErrorReason(GeckoTerminalException error) {
  final status = error.statusCode;
  final statusText = status == null ? '' : ' HTTP $status.';
  return '${error.message}$statusText';
}
