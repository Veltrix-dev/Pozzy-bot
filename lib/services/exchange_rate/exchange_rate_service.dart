import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:pozzy_bot/config/config.dart';
import 'package:pozzy_bot/database/models/rub_amount.dart';
import 'package:pozzy_bot/database/models/usd_amount.dart';
import 'package:pozzy_bot/services/exchange_rate/exchange_rate_exception.dart';
import 'package:pozzy_bot/services/exchange_rate/exchange_rate_notifier.dart';
import 'package:pozzy_bot/services/exchange_rate/exchange_rate_store.dart';
import 'package:pozzy_bot/utils/bot_log.dart';

class ExchangeRateService {
  ExchangeRateService({
    required String twelveDataApiKey,
    required String exchangeRateApiKey,
    required ExchangeRateStore store,
    Uri? twelveDataBaseUri,
    Uri? exchangeRateApiBaseUri,
    http.Client? twelveDataHttpClient,
    http.Client? exchangeRateApiHttpClient,
    ExchangeRateNotifier notifier = const SilentExchangeRateNotifier(),
    Duration timeout = const Duration(seconds: 15),
    Duration primaryRefreshInterval = const Duration(minutes: 5),
    Duration primaryMaximumAge = const Duration(hours: 2),
    Duration primarySourceMaximumAge = const Duration(hours: 2),
    Duration fallbackRefreshInterval = const Duration(days: 1),
    Duration fallbackRetryInterval = const Duration(hours: 1),
    Duration fallbackMaximumAge = const Duration(hours: 26),
    Duration absoluteMaximumAge = const Duration(days: 3),
    Duration allowedClockSkew = const Duration(minutes: 5),
    double minimumRate = 10,
    double maximumRate = 500,
    double maximumChangePercent = 20,
    double maximumProviderDifferencePercent = 10,
    DateTime Function()? clock,
    Random? random,
  }) : _twelveDataApiKey = _validateApiKey(
         twelveDataApiKey,
         'TWELVE_DATA_API_KEY',
       ),
       _exchangeRateApiKey = _validateApiKey(
         exchangeRateApiKey,
         'EXCHANGE_RATE_API_KEY',
       ),
       _store = store,
       _twelveDataBaseUri = _validateBaseUri(
         twelveDataBaseUri ?? Uri.parse('https://api.twelvedata.com/'),
         'Twelve Data',
       ),
       _exchangeRateApiBaseUri = _validateBaseUri(
         exchangeRateApiBaseUri ??
             Uri.parse('https://v6.exchangerate-api.com/v6/'),
         'ExchangeRate-API',
       ),
       _twelveDataHttpClient = twelveDataHttpClient ?? http.Client(),
       _exchangeRateApiHttpClient = exchangeRateApiHttpClient ?? http.Client(),
       _notifier = notifier,
       _timeout = _validateDuration(timeout, 'timeout'),
       _primaryRefreshInterval = _validateDuration(
         primaryRefreshInterval,
         'primaryRefreshInterval',
       ),
       _primaryMaximumAge = _validatePrimaryMaximumAge(
         primaryMaximumAge,
         primaryRefreshInterval,
       ),
       _primarySourceMaximumAge = _validateMaximumAge(
         primarySourceMaximumAge,
         absoluteMaximumAge,
         'primarySourceMaximumAge',
       ),
       _fallbackRefreshInterval = _validateDuration(
         fallbackRefreshInterval,
         'fallbackRefreshInterval',
       ),
       _fallbackRetryInterval = _validateDuration(
         fallbackRetryInterval,
         'fallbackRetryInterval',
       ),
       _fallbackMaximumAge = _validateMaximumAge(
         fallbackMaximumAge,
         absoluteMaximumAge,
         'fallbackMaximumAge',
       ),
       _absoluteMaximumAge = _validateDuration(
         absoluteMaximumAge,
         'absoluteMaximumAge',
       ),
       _allowedClockSkew = _validateDuration(
         allowedClockSkew,
         'allowedClockSkew',
       ),
       _minimumRate = _validatePositiveNumber(minimumRate, 'minimumRate'),
       _maximumRate = _validateRateMaximum(maximumRate, minimumRate),
       _maximumChangePercent = _validatePositiveNumber(
         maximumChangePercent,
         'maximumChangePercent',
       ),
       _maximumProviderDifferencePercent = _validatePositiveNumber(
         maximumProviderDifferencePercent,
         'maximumProviderDifferencePercent',
       ),
       _clock = clock ?? DateTime.now,
       _random = random ?? Random.secure() {
    if (_primaryMaximumAge > _absoluteMaximumAge) {
      throw const ExchangeRateException(
        kind: ExchangeRateErrorKind.configuration,
        message: 'primaryMaximumAge must not exceed absoluteMaximumAge',
      );
    }
  }

  factory ExchangeRateService.fromConfig({
    required ExchangeRateStore store,
    required ExchangeRateNotifier notifier,
    http.Client? twelveDataHttpClient,
    http.Client? exchangeRateApiHttpClient,
    DateTime Function()? clock,
  }) {
    return ExchangeRateService(
      twelveDataApiKey: Config.twelveDataApiKey,
      exchangeRateApiKey: Config.exchangeRateApiKey,
      store: store,
      twelveDataBaseUri: Uri.parse(Config.twelveDataApiBaseUrl),
      exchangeRateApiBaseUri: Uri.parse(Config.exchangeRateApiBaseUrl),
      twelveDataHttpClient: twelveDataHttpClient,
      exchangeRateApiHttpClient: exchangeRateApiHttpClient,
      notifier: notifier,
      timeout: Duration(seconds: Config.exchangeRateApiTimeoutSeconds),
      primaryRefreshInterval: Duration(
        seconds: Config.exchangeRateRefreshSeconds,
      ),
      primaryMaximumAge: Duration(
        seconds: Config.exchangeRatePrimaryMaximumAgeSeconds,
      ),
      primarySourceMaximumAge: Duration(
        seconds: Config.exchangeRatePrimarySourceMaximumAgeSeconds,
      ),
      fallbackRefreshInterval: Duration(
        seconds: Config.exchangeRateFallbackRefreshSeconds,
      ),
      fallbackRetryInterval: Duration(
        seconds: Config.exchangeRateFallbackRetrySeconds,
      ),
      fallbackMaximumAge: Duration(
        seconds: Config.exchangeRateFallbackMaximumAgeSeconds,
      ),
      absoluteMaximumAge: Duration(
        seconds: Config.exchangeRateAbsoluteMaximumAgeSeconds,
      ),
      allowedClockSkew: Duration(
        seconds: Config.exchangeRateAllowedClockSkewSeconds,
      ),
      minimumRate: _parseConfiguredDouble(
        Config.exchangeRateMinimumRaw,
        'EXCHANGE_RATE_MIN_USD_RUB',
      ),
      maximumRate: _parseConfiguredDouble(
        Config.exchangeRateMaximumRaw,
        'EXCHANGE_RATE_MAX_USD_RUB',
      ),
      maximumChangePercent: _parseConfiguredDouble(
        Config.exchangeRateMaximumChangePercentRaw,
        'EXCHANGE_RATE_MAX_CHANGE_PERCENT',
      ),
      maximumProviderDifferencePercent: _parseConfiguredDouble(
        Config.exchangeRateMaximumProviderDifferencePercentRaw,
        'EXCHANGE_RATE_MAX_PROVIDER_DIFFERENCE_PERCENT',
      ),
      clock: clock,
    );
  }

  final String _twelveDataApiKey;
  final String _exchangeRateApiKey;
  final ExchangeRateStore _store;
  final Uri _twelveDataBaseUri;
  final Uri _exchangeRateApiBaseUri;
  final http.Client _twelveDataHttpClient;
  final http.Client _exchangeRateApiHttpClient;
  final ExchangeRateNotifier _notifier;
  final Duration _timeout;
  final Duration _primaryRefreshInterval;
  final Duration _primaryMaximumAge;
  final Duration _primarySourceMaximumAge;
  final Duration _fallbackRefreshInterval;
  final Duration _fallbackRetryInterval;
  final Duration _fallbackMaximumAge;
  final Duration _absoluteMaximumAge;
  final Duration _allowedClockSkew;
  final double _minimumRate;
  final double _maximumRate;
  final double _maximumChangePercent;
  final double _maximumProviderDifferencePercent;
  final DateTime Function() _clock;
  final Random _random;

  Timer? _primaryRefreshTimer;
  Timer? _fallbackRefreshTimer;
  Future<void>? _startFuture;
  Future<void>? _primaryRefresh;
  Future<void>? _fallbackRefresh;
  Future<void>? _modeUpdate;
  _ExchangeRateMode? _lastMode;
  int _primaryFailures = 0;
  int _fallbackFailures = 0;
  ExchangeRateException? _lastPrimaryError;
  ExchangeRateException? _lastFallbackError;
  final Map<ExchangeRateSource, ExchangeRateErrorKind> _lastRejections = {};
  bool _closed = false;

  Future<void> start() {
    final activeStart = _startFuture;
    if (activeStart != null) return activeStart;

    final start = _startWithRetryableFailure();
    _startFuture = start;
    return start;
  }

  Future<void> _startWithRetryableFailure() async {
    try {
      await _start();
    } catch (_) {
      _startFuture = null;
      rethrow;
    }
  }

  Future<RubAmount> convertUsdToRub(UsdAmount usdAmount) async {
    if (usdAmount.isZero) {
      throw const ExchangeRateException(
        kind: ExchangeRateErrorKind.invalidAmount,
        message: 'USD amount must be greater than zero',
      );
    }
    BotLog.debug('currency_conversion requested pair=USD_RUB');

    final snapshot = await getSnapshot();
    final rubAmount = convertUsingSnapshot(usdAmount, snapshot);
    BotLog.debug(
      'currency_conversion completed pair=USD_RUB '
      'source=${snapshot.source.name} mode=${snapshot.mode.name}',
    );
    return rubAmount;
  }

  Future<ExchangeRateSnapshot> getSnapshot() async {
    await _updateMode();
    return _snapshotFromSelection(_selectRate());
  }

  RubAmount convertUsingSnapshot(
    UsdAmount usdAmount,
    ExchangeRateSnapshot snapshot,
  ) => convertUsdToRubAtFixedRate(usdAmount, snapshot.rateMicros);

  RubAmount convertUsdToRubAtFixedRate(UsdAmount usdAmount, int rateMicros) {
    if (usdAmount.isZero) {
      throw const ExchangeRateException(
        kind: ExchangeRateErrorKind.invalidAmount,
        message: 'USD amount must be greater than zero',
      );
    }
    if (rateMicros <= 0) {
      throw const ExchangeRateException(
        kind: ExchangeRateErrorKind.invalidAmount,
        message: 'USD/RUB rate must be greater than zero',
      );
    }
    final product = usdAmount.micros * rateMicros;
    final rubMicros = (product + 500000) ~/ 1000000;
    if (rubMicros <= 0) {
      throw const ExchangeRateException(
        kind: ExchangeRateErrorKind.invalidAmount,
        message: 'USD amount is outside the supported numeric range',
      );
    }
    return RubAmount.fromMicros(rubMicros);
  }

  Future<void> _start() async {
    BotLog.info(
      'exchange_rate initialization_started pair=USD_RUB '
      'providers=twelveData,exchangeRateApi',
    );
    final primarySucceeded = await _refreshPrimarySafely();
    final fallbackSucceeded = await _refreshFallbackSafely();
    _logStartupProviderResult(
      source: ExchangeRateSource.twelveData,
      succeeded: primarySucceeded,
    );
    _logStartupProviderResult(
      source: ExchangeRateSource.exchangeRateApi,
      succeeded: fallbackSucceeded,
    );
    await _updateMode();
    _schedulePrimaryRefresh(
      _refreshDelay(_primaryRefreshInterval, _primaryFailures),
    );
    _scheduleFallbackRefresh(_fallbackDelayAfterAttempt(fallbackSucceeded));
    BotLog.info(
      'exchange_rate initialization_completed pair=USD_RUB '
      'effective_source=${_effectiveSourceName()}',
    );
  }

  Duration _remainingUntilFallbackRefresh(StoredExchangeRate? stored) {
    if (stored == null) return Duration.zero;
    final elapsed = _clock().toUtc().difference(stored.fetchedAt);
    if (elapsed >= _fallbackRefreshInterval) return Duration.zero;
    if (elapsed.isNegative) return _fallbackRefreshInterval;
    return _fallbackRefreshInterval - elapsed;
  }

  Duration _fallbackDelayAfterAttempt(bool succeeded) {
    if (!succeeded) {
      return _refreshDelay(_fallbackRetryInterval, _fallbackFailures);
    }
    final stored = _safeFind(ExchangeRateSource.exchangeRateApi);
    final remaining = _remainingUntilFallbackRefresh(stored);
    return remaining > Duration.zero ? remaining : _fallbackRetryInterval;
  }

  void _schedulePrimaryRefresh(Duration delay) {
    if (_closed) return;
    _primaryRefreshTimer?.cancel();
    _primaryRefreshTimer = Timer(delay, () async {
      await _refreshPrimarySafely();
      await _updateMode();
      _schedulePrimaryRefresh(
        _refreshDelay(_primaryRefreshInterval, _primaryFailures),
      );
    });
  }

  void _scheduleFallbackRefresh(Duration delay) {
    if (_closed) return;
    _fallbackRefreshTimer?.cancel();
    _fallbackRefreshTimer = Timer(delay, () async {
      final succeeded = await _refreshFallbackSafely();
      await _updateMode();
      _scheduleFallbackRefresh(_fallbackDelayAfterAttempt(succeeded));
    });
  }

  Future<bool> _refreshPrimarySafely() async {
    try {
      await _refreshPrimaryRate();
      _primaryFailures = 0;
      _lastPrimaryError = null;
      return true;
    } on ExchangeRateException catch (error) {
      _primaryFailures++;
      _lastPrimaryError = error;
      _logRefreshFailure(ExchangeRateSource.twelveData, error);
      return false;
    }
  }

  Future<bool> _refreshFallbackSafely() async {
    try {
      await _refreshFallbackRate();
      _fallbackFailures = 0;
      _lastFallbackError = null;
      return true;
    } on ExchangeRateException catch (error) {
      _fallbackFailures++;
      _lastFallbackError = error;
      _logRefreshFailure(ExchangeRateSource.exchangeRateApi, error);
      return false;
    }
  }

  Future<void> _refreshPrimaryRate() {
    final active = _primaryRefresh;
    if (active != null) return active;

    final refresh = _fetchAndStore(ExchangeRateSource.twelveData);
    _primaryRefresh = refresh;
    return refresh.whenComplete(() => _primaryRefresh = null);
  }

  Future<void> _refreshFallbackRate() {
    final active = _fallbackRefresh;
    if (active != null) return active;

    final refresh = _fetchAndStore(ExchangeRateSource.exchangeRateApi);
    _fallbackRefresh = refresh;
    return refresh.whenComplete(() => _fallbackRefresh = null);
  }

  Future<void> _fetchAndStore(ExchangeRateSource source) async {
    BotLog.debug(
      'exchange_rate request_started pair=USD_RUB source=${source.name}',
    );
    try {
      final result = switch (source) {
        ExchangeRateSource.twelveData => await _fetchTwelveDataRate(),
        ExchangeRateSource.exchangeRateApi => await _fetchExchangeRateApiRate(),
      };
      _validateCandidate(source, result);
      _store.saveUsdToRub(
        source: source,
        rate: result.rate,
        sourceUpdatedAt: result.sourceUpdatedAt,
        fetchedAt: _clock().toUtc(),
      );
      _lastRejections.remove(source);
      BotLog.debug(
        'exchange_rate valid_rate_stored pair=USD_RUB source=${source.name}',
      );
    } on TimeoutException {
      throw const ExchangeRateException(
        kind: ExchangeRateErrorKind.timeout,
        message: 'Exchange rate request timed out',
      );
    } on SocketException {
      throw const ExchangeRateException(
        kind: ExchangeRateErrorKind.network,
        message: 'Exchange rate provider is unavailable',
      );
    } on http.ClientException {
      throw const ExchangeRateException(
        kind: ExchangeRateErrorKind.network,
        message: 'Exchange rate HTTP request failed',
      );
    } on ExchangeRateStoreException {
      throw const ExchangeRateException(
        kind: ExchangeRateErrorKind.storage,
        message: 'Exchange rate storage operation failed',
      );
    } on ExchangeRateException {
      rethrow;
    } catch (_) {
      throw const ExchangeRateException(
        kind: ExchangeRateErrorKind.unexpected,
        message: 'Unexpected exchange rate request failure',
      );
    }
  }

  Future<_FetchedExchangeRate> _fetchTwelveDataRate() async {
    final endpoint = _twelveDataBaseUri
        .resolve('exchange_rate')
        .replace(queryParameters: const {'symbol': 'USD/RUB'});
    final response = await _twelveDataHttpClient
        .get(endpoint, headers: {'Authorization': 'apikey $_twelveDataApiKey'})
        .timeout(_timeout);
    return _parseTwelveDataResponse(response);
  }

  Future<_FetchedExchangeRate> _fetchExchangeRateApiRate() async {
    final key = Uri.encodeComponent(_exchangeRateApiKey);
    final endpoint = _exchangeRateApiBaseUri.resolve('$key/latest/USD');
    final response = await _exchangeRateApiHttpClient
        .get(endpoint)
        .timeout(_timeout);
    return _parseExchangeRateApiResponse(response);
  }

  _FetchedExchangeRate _parseTwelveDataResponse(http.Response response) {
    final payload = _decodePayload(response);
    _validateHttpResponse(
      response: response,
      payload: payload,
      isApiError: payload?['status'] == 'error',
      provider: 'Twelve Data',
      apiError: payload?['code'],
    );
    if (payload == null || payload['symbol'] != 'USD/RUB') {
      throw const ExchangeRateException(
        kind: ExchangeRateErrorKind.malformedResponse,
        message: 'Twelve Data returned an unexpected response',
      );
    }

    return _parseRateAndTimestamp(
      rate: payload['rate'],
      timestamp: payload['timestamp'],
      provider: 'Twelve Data',
    );
  }

  _FetchedExchangeRate _parseExchangeRateApiResponse(http.Response response) {
    final payload = _decodePayload(response);
    _validateHttpResponse(
      response: response,
      payload: payload,
      isApiError: payload?['result'] == 'error',
      provider: 'ExchangeRate-API',
      apiError: payload?['error-type'],
    );
    if (payload == null ||
        payload['result'] != 'success' ||
        payload['base_code'] != 'USD') {
      throw const ExchangeRateException(
        kind: ExchangeRateErrorKind.malformedResponse,
        message: 'ExchangeRate-API returned an unexpected response',
      );
    }

    final rates = payload['conversion_rates'];
    final rubRate = rates is Map<String, dynamic> ? rates['RUB'] : null;
    return _parseRateAndTimestamp(
      rate: rubRate,
      timestamp: payload['time_last_update_unix'],
      provider: 'ExchangeRate-API',
    );
  }

  void _validateCandidate(
    ExchangeRateSource source,
    _FetchedExchangeRate candidate,
  ) {
    ExchangeRateException? rejection;
    if (candidate.rate < _minimumRate || candidate.rate > _maximumRate) {
      rejection = const ExchangeRateException(
        kind: ExchangeRateErrorKind.suspiciousRate,
        message: 'USD/RUB rate is outside the configured safe range',
      );
    } else if (!_isAgeAllowed(
      candidate.sourceUpdatedAt,
      source == ExchangeRateSource.twelveData
          ? _primarySourceMaximumAge
          : _absoluteMaximumAge,
    )) {
      rejection = const ExchangeRateException(
        kind: ExchangeRateErrorKind.staleRate,
        message: 'Exchange rate provider returned a stale timestamp',
      );
    } else {
      final previous = _safeFind(source);
      final other = _safeFind(_otherSource(source));
      final changedTooMuch =
          previous != null &&
          _percentageDifference(candidate.rate, previous.rate) >
              _maximumChangePercent;
      final otherIsUsable = other != null && _isWithinAbsoluteMaximumAge(other);
      final differsFromOther =
          otherIsUsable &&
          _percentageDifference(candidate.rate, other.rate) >
              _maximumProviderDifferencePercent;
      if (differsFromOther) {
        rejection = const ExchangeRateException(
          kind: ExchangeRateErrorKind.providerMismatch,
          message: 'USD/RUB providers returned conflicting rates',
        );
      } else if (changedTooMuch && !otherIsUsable) {
        rejection = const ExchangeRateException(
          kind: ExchangeRateErrorKind.suspiciousRate,
          message: 'Large USD/RUB rate change is not confirmed',
        );
      }
    }

    if (rejection == null) return;
    try {
      _store.saveRejectedUsdToRub(
        source: source,
        rate: candidate.rate,
        sourceUpdatedAt: candidate.sourceUpdatedAt,
        fetchedAt: _clock().toUtc(),
        reason: rejection.kind.name,
      );
    } on ExchangeRateStoreException catch (error) {
      BotLog.error(
        'exchange_rate rejected_observation_write_failed '
        'source=${source.name} error=${error.runtimeType}',
      );
    }
    throw rejection;
  }

  void _validateHttpResponse({
    required http.Response response,
    required Map<String, dynamic>? payload,
    required bool isApiError,
    required String provider,
    required Object? apiError,
  }) {
    if (response.statusCode == 200 && !isApiError) {
      if (payload == null) {
        throw ExchangeRateException(
          kind: ExchangeRateErrorKind.malformedResponse,
          message: '$provider returned invalid JSON',
        );
      }
      return;
    }
    if (isApiError) {
      throw ExchangeRateException(
        kind: ExchangeRateErrorKind.apiRejected,
        message: '$provider rejected the rate request',
        statusCode: response.statusCode,
        apiErrorType: _safeApiErrorType(apiError),
      );
    }
    throw ExchangeRateException(
      kind: response.statusCode >= 500
          ? ExchangeRateErrorKind.httpServer
          : ExchangeRateErrorKind.httpClient,
      message: '$provider returned an HTTP error',
      statusCode: response.statusCode,
    );
  }

  _FetchedExchangeRate _parseRateAndTimestamp({
    required Object? rate,
    required Object? timestamp,
    required String provider,
  }) {
    final parsedRate = _parsePositiveDouble(rate);
    final parsedTimestamp = _parsePositiveInt(timestamp);
    if (parsedRate == null || parsedTimestamp == null) {
      throw ExchangeRateException(
        kind: ExchangeRateErrorKind.malformedResponse,
        message: '$provider returned an invalid USD/RUB rate',
      );
    }
    return _FetchedExchangeRate(
      rate: parsedRate,
      sourceUpdatedAt: DateTime.fromMillisecondsSinceEpoch(
        parsedTimestamp * 1000,
        isUtc: true,
      ),
    );
  }

  Map<String, dynamic>? _decodePayload(http.Response response) {
    if (response.body.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  _RateSelection _selectRate() {
    final primary = _safeFind(ExchangeRateSource.twelveData);
    final fallback = _safeFind(ExchangeRateSource.exchangeRateApi);
    if (primary != null && _isFresh(primary, _primaryMaximumAge)) {
      return _RateSelection(_ExchangeRateMode.primary, primary);
    }
    if (fallback != null && _isFresh(fallback, _fallbackMaximumAge)) {
      return _RateSelection(_ExchangeRateMode.fallback, fallback);
    }
    final emergency = [primary, fallback]
        .whereType<StoredExchangeRate>()
        .where(_isWithinAbsoluteMaximumAge)
        .fold<StoredExchangeRate?>(
          null,
          (latest, rate) =>
              latest == null || rate.fetchedAt.isAfter(latest.fetchedAt)
              ? rate
              : latest,
        );
    if (emergency != null) {
      return _RateSelection(_ExchangeRateMode.emergency, emergency);
    }
    if (primary != null || fallback != null) {
      throw const ExchangeRateException(
        kind: ExchangeRateErrorKind.staleRate,
        message: 'All confirmed USD/RUB exchange rates are too old',
      );
    }
    throw const ExchangeRateException(
      kind: ExchangeRateErrorKind.missingRubRate,
      message: 'No confirmed USD/RUB exchange rate is stored',
    );
  }

  bool _isFresh(StoredExchangeRate stored, Duration maximumFetchedAge) {
    final maximumSourceAge = stored.source == ExchangeRateSource.twelveData
        ? _primarySourceMaximumAge
        : _absoluteMaximumAge;
    return _isAgeAllowed(stored.fetchedAt, maximumFetchedAge) &&
        _isAgeAllowed(stored.sourceUpdatedAt, maximumSourceAge);
  }

  bool _isWithinAbsoluteMaximumAge(StoredExchangeRate stored) {
    return _isAgeAllowed(stored.fetchedAt, _absoluteMaximumAge) &&
        _isAgeAllowed(stored.sourceUpdatedAt, _absoluteMaximumAge);
  }

  bool _isAgeAllowed(DateTime timestamp, Duration maximumAge) {
    final age = _clock().toUtc().difference(timestamp.toUtc());
    if (age.isNegative) return -age <= _allowedClockSkew;
    return age <= maximumAge;
  }

  StoredExchangeRate? _safeFind(ExchangeRateSource source) {
    try {
      return _store.findUsdToRub(source);
    } on ExchangeRateStoreException catch (error) {
      BotLog.error(
        'exchange_rate storage_read_failed source=${source.name} '
        'error=${error.runtimeType}',
      );
      if (_lastRejections[source] != ExchangeRateErrorKind.storage) {
        _lastRejections[source] = ExchangeRateErrorKind.storage;
        unawaited(
          _notifier.notifyRateRejected(
            source: source,
            reason: ExchangeRateErrorKind.storage.name,
          ),
        );
      }
      return null;
    }
  }

  Duration _refreshDelay(Duration base, int failures) {
    if (failures <= 0) return base;
    final exponent = min(failures - 1, 4);
    final multiplier = 1 << exponent;
    final rawMilliseconds = base.inMilliseconds * multiplier;
    final cappedMilliseconds = min(
      rawMilliseconds,
      const Duration(hours: 24).inMilliseconds,
    );
    final jitter = 0.9 + _random.nextDouble() * 0.2;
    return Duration(milliseconds: (cappedMilliseconds * jitter).round());
  }

  Future<void> _updateMode() {
    final active = _modeUpdate;
    if (active != null) return active;

    final update = _updateModeInternal();
    _modeUpdate = update;
    return update.whenComplete(() => _modeUpdate = null);
  }

  Future<void> _updateModeInternal() async {
    try {
      _applyMode(_selectRate());
    } on ExchangeRateException catch (error) {
      if (error.kind == ExchangeRateErrorKind.missingRubRate ||
          error.kind == ExchangeRateErrorKind.staleRate) {
        BotLog.error('exchange_rate no_confirmed_rate pair=USD_RUB');
        if (_lastMode != _ExchangeRateMode.unavailable) {
          _lastMode = _ExchangeRateMode.unavailable;
          unawaited(_notifier.notifyUnavailable(error.kind.name));
        }
        return;
      }
      rethrow;
    }
  }

  void _applyMode(_RateSelection selection) {
    final previous = _lastMode;
    if (previous == selection.mode) return;
    _lastMode = selection.mode;

    switch (selection.mode) {
      case _ExchangeRateMode.primary:
        if (previous != null && previous != _ExchangeRateMode.primary) {
          unawaited(_notifier.notifyPrimaryRestored(selection.rate));
        }
      case _ExchangeRateMode.fallback:
        unawaited(
          _notifier.notifyFallbackActivated(
            fallback: selection.rate,
            primary: _safeFind(ExchangeRateSource.twelveData),
          ),
        );
      case _ExchangeRateMode.emergency:
        unawaited(_notifier.notifyEmergencyRateActivated(selection.rate));
      case _ExchangeRateMode.unavailable:
        break;
    }
  }

  void _logRefreshFailure(
    ExchangeRateSource source,
    ExchangeRateException error,
  ) {
    BotLog.error(
      'exchange_rate refresh_failed pair=USD_RUB source=${source.name} '
      'kind=${error.kind.name} status=${error.statusCode ?? 'none'} '
      'api_error=${error.apiErrorType ?? 'none'}',
    );
    if (error.kind == ExchangeRateErrorKind.suspiciousRate ||
        error.kind == ExchangeRateErrorKind.providerMismatch ||
        error.kind == ExchangeRateErrorKind.staleRate) {
      if (_lastRejections[source] != error.kind) {
        _lastRejections[source] = error.kind;
        unawaited(
          _notifier.notifyRateRejected(source: source, reason: error.kind.name),
        );
      }
    }
  }

  void _logStartupProviderResult({
    required ExchangeRateSource source,
    required bool succeeded,
  }) {
    final stored = _safeFind(source);
    BotLog.info(
      'exchange_rate provider_check source=${source.name} '
      'status=${succeeded ? 'success' : 'error'} '
      'stored=${stored == null ? 'none' : 'available'}',
    );
  }

  String _effectiveSourceName() {
    try {
      return _selectRate().rate.source.name;
    } on ExchangeRateException {
      return 'none';
    }
  }

  ExchangeRateStatus get status {
    final primary = _safeFind(ExchangeRateSource.twelveData);
    final fallback = _safeFind(ExchangeRateSource.exchangeRateApi);
    try {
      final selection = _selectRate();
      final snapshot = _snapshotFromSelection(selection);
      return ExchangeRateStatus(
        mode: snapshot.mode,
        activeSource: snapshot.source,
        primary: primary,
        fallback: fallback,
        primaryFailures: _primaryFailures,
        fallbackFailures: _fallbackFailures,
        lastPrimaryError: _lastPrimaryError,
        lastFallbackError: _lastFallbackError,
      );
    } on ExchangeRateException {
      return ExchangeRateStatus(
        mode: ExchangeRateMode.unavailable,
        primary: primary,
        fallback: fallback,
        primaryFailures: _primaryFailures,
        fallbackFailures: _fallbackFailures,
        lastPrimaryError: _lastPrimaryError,
        lastFallbackError: _lastFallbackError,
      );
    }
  }

  ExchangeRateSnapshot _snapshotFromSelection(_RateSelection selection) {
    return ExchangeRateSnapshot(
      source: selection.rate.source,
      rateMicros: selection.rate.rateMicros,
      sourceUpdatedAt: selection.rate.sourceUpdatedAt,
      fetchedAt: selection.rate.fetchedAt,
      mode: switch (selection.mode) {
        _ExchangeRateMode.primary => ExchangeRateMode.primary,
        _ExchangeRateMode.fallback => ExchangeRateMode.fallback,
        _ExchangeRateMode.emergency => ExchangeRateMode.emergency,
        _ExchangeRateMode.unavailable => ExchangeRateMode.unavailable,
      },
    );
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _primaryRefreshTimer?.cancel();
    _fallbackRefreshTimer?.cancel();
    _primaryRefreshTimer = null;
    _fallbackRefreshTimer = null;
    final activeRefreshes = <Future<void>>[];
    final primaryRefresh = _primaryRefresh;
    final fallbackRefresh = _fallbackRefresh;
    if (primaryRefresh != null) activeRefreshes.add(primaryRefresh);
    if (fallbackRefresh != null) activeRefreshes.add(fallbackRefresh);
    await Future.wait<void>(activeRefreshes).catchError((_) => <void>[]);
    _twelveDataHttpClient.close();
    _exchangeRateApiHttpClient.close();
  }
}

enum _ExchangeRateMode { primary, fallback, emergency, unavailable }

enum ExchangeRateMode { primary, fallback, emergency, unavailable }

class ExchangeRateSnapshot {
  const ExchangeRateSnapshot({
    required this.source,
    required this.rateMicros,
    required this.sourceUpdatedAt,
    required this.fetchedAt,
    required this.mode,
  });

  final ExchangeRateSource source;
  final int rateMicros;
  final DateTime sourceUpdatedAt;
  final DateTime fetchedAt;
  final ExchangeRateMode mode;

  double get rate => rateMicros / 1000000;
}

class ExchangeRateStatus {
  const ExchangeRateStatus({
    required this.mode,
    required this.primary,
    required this.fallback,
    required this.primaryFailures,
    required this.fallbackFailures,
    required this.lastPrimaryError,
    required this.lastFallbackError,
    this.activeSource,
  });

  final ExchangeRateMode mode;
  final ExchangeRateSource? activeSource;
  final StoredExchangeRate? primary;
  final StoredExchangeRate? fallback;
  final int primaryFailures;
  final int fallbackFailures;
  final ExchangeRateException? lastPrimaryError;
  final ExchangeRateException? lastFallbackError;
}

class _RateSelection {
  const _RateSelection(this.mode, this.rate);

  final _ExchangeRateMode mode;
  final StoredExchangeRate rate;
}

class _FetchedExchangeRate {
  const _FetchedExchangeRate({
    required this.rate,
    required this.sourceUpdatedAt,
  });

  final double rate;
  final DateTime sourceUpdatedAt;
}

String _validateApiKey(String apiKey, String name) {
  final value = apiKey.trim();
  if (value.isEmpty) {
    throw ExchangeRateException(
      kind: ExchangeRateErrorKind.configuration,
      message: '$name is not configured',
    );
  }
  return value;
}

Uri _validateBaseUri(Uri uri, String provider) {
  final isLoopback =
      uri.host == 'localhost' || uri.host == '127.0.0.1' || uri.host == '::1';
  if (!uri.hasScheme || (!isLoopback && uri.scheme != 'https')) {
    throw ExchangeRateException(
      kind: ExchangeRateErrorKind.configuration,
      message: '$provider base URL must use HTTPS',
    );
  }
  return uri.replace(path: uri.path.endsWith('/') ? uri.path : '${uri.path}/');
}

Duration _validateDuration(Duration duration, String name) {
  if (duration <= Duration.zero) {
    throw ExchangeRateException(
      kind: ExchangeRateErrorKind.configuration,
      message: '$name must be greater than zero',
    );
  }
  return duration;
}

Duration _validatePrimaryMaximumAge(
  Duration maximumAge,
  Duration refreshInterval,
) {
  _validateDuration(maximumAge, 'primaryMaximumAge');
  if (maximumAge < refreshInterval) {
    throw const ExchangeRateException(
      kind: ExchangeRateErrorKind.configuration,
      message: 'primaryMaximumAge must not be shorter than refreshInterval',
    );
  }
  return maximumAge;
}

Duration _validateMaximumAge(
  Duration maximumAge,
  Duration absoluteMaximumAge,
  String name,
) {
  _validateDuration(maximumAge, name);
  if (maximumAge > absoluteMaximumAge) {
    throw ExchangeRateException(
      kind: ExchangeRateErrorKind.configuration,
      message: '$name must not exceed absoluteMaximumAge',
    );
  }
  return maximumAge;
}

double _validatePositiveNumber(double value, String name) {
  if (!value.isFinite || value <= 0) {
    throw ExchangeRateException(
      kind: ExchangeRateErrorKind.configuration,
      message: '$name must be a positive finite number',
    );
  }
  return value;
}

double _validateRateMaximum(double maximum, double minimum) {
  _validatePositiveNumber(maximum, 'maximumRate');
  if (maximum <= minimum) {
    throw const ExchangeRateException(
      kind: ExchangeRateErrorKind.configuration,
      message: 'maximumRate must be greater than minimumRate',
    );
  }
  return maximum;
}

double _parseConfiguredDouble(String raw, String name) {
  final value = double.tryParse(raw);
  if (value == null || !value.isFinite || value <= 0) {
    throw ExchangeRateException(
      kind: ExchangeRateErrorKind.configuration,
      message: '$name must be a positive finite number',
    );
  }
  return value;
}

double? _parsePositiveDouble(Object? value) {
  final parsed = value is num
      ? value.toDouble()
      : value is String
      ? double.tryParse(value)
      : null;
  if (parsed == null || !parsed.isFinite || parsed <= 0) return null;
  return parsed;
}

int? _parsePositiveInt(Object? value) {
  final parsed = value is int
      ? value
      : value is num
      ? value.toInt()
      : value is String
      ? int.tryParse(value)
      : null;
  if (parsed == null || parsed <= 0) return null;
  return parsed;
}

String _safeApiErrorType(Object? value) {
  final normalized = value
      ?.toString()
      .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '')
      .trim();
  if (normalized == null || normalized.isEmpty) return 'unknown';
  return normalized.length <= 100 ? normalized : normalized.substring(0, 100);
}

ExchangeRateSource _otherSource(ExchangeRateSource source) => switch (source) {
  ExchangeRateSource.twelveData => ExchangeRateSource.exchangeRateApi,
  ExchangeRateSource.exchangeRateApi => ExchangeRateSource.twelveData,
};

double _percentageDifference(double first, double second) {
  return ((first - second).abs() / second) * 100;
}
