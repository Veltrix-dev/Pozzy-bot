import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:pozzy_bot/config/config.dart';
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
    Duration fallbackRefreshInterval = const Duration(days: 1),
    Duration fallbackRetryInterval = const Duration(hours: 1),
    DateTime Function()? clock,
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
       _fallbackRefreshInterval = _validateDuration(
         fallbackRefreshInterval,
         'fallbackRefreshInterval',
       ),
       _fallbackRetryInterval = _validateDuration(
         fallbackRetryInterval,
         'fallbackRetryInterval',
       ),
       _clock = clock ?? DateTime.now;

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
      fallbackRefreshInterval: Duration(
        seconds: Config.exchangeRateFallbackRefreshSeconds,
      ),
      fallbackRetryInterval: Duration(
        seconds: Config.exchangeRateFallbackRetrySeconds,
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
  final Duration _fallbackRefreshInterval;
  final Duration _fallbackRetryInterval;
  final DateTime Function() _clock;

  Timer? _primaryRefreshTimer;
  Timer? _fallbackRefreshTimer;
  Future<void>? _startFuture;
  Future<void>? _primaryRefresh;
  Future<void>? _fallbackRefresh;
  Future<void>? _modeUpdate;
  _ExchangeRateMode? _lastMode;
  bool _closed = false;

  Future<void> start() {
    final activeStart = _startFuture;
    if (activeStart != null) return activeStart;

    final start = _start();
    _startFuture = start;
    return start;
  }

  Future<double> convertUsdToRub(double usdAmount) async {
    _validateUsdAmount(usdAmount);
    BotLog.debug('currency_conversion requested pair=USD_RUB');

    await _updateMode();
    final selection = _selectRate();
    final rubAmount = usdAmount * selection.rate.rate;
    if (!rubAmount.isFinite || rubAmount <= 0) {
      throw const ExchangeRateException(
        kind: ExchangeRateErrorKind.invalidAmount,
        message: 'USD amount is outside the supported numeric range',
      );
    }

    BotLog.debug(
      'currency_conversion completed pair=USD_RUB '
      'source=${selection.rate.source.name}',
    );
    return rubAmount;
  }

  Future<void> _start() async {
    BotLog.info(
      'exchange_rate initialization_started pair=USD_RUB '
      'providers=twelveData,exchangeRateApi',
    );
    final results = await Future.wait([
      _refreshPrimarySafely(),
      _refreshFallbackSafely(),
    ]);
    final primarySucceeded = results[0];
    final fallbackSucceeded = results[1];
    _logStartupProviderResult(
      source: ExchangeRateSource.twelveData,
      succeeded: primarySucceeded,
    );
    _logStartupProviderResult(
      source: ExchangeRateSource.exchangeRateApi,
      succeeded: fallbackSucceeded,
    );
    await _updateMode();
    _schedulePrimaryRefresh(_primaryRefreshInterval);
    _scheduleFallbackRefresh(_fallbackDelayAfterAttempt(fallbackSucceeded));
    BotLog.info(
      'exchange_rate initialization_completed pair=USD_RUB '
      'effective_source=${_effectiveSourceName()}',
    );
  }

  Duration _remainingUntilFallbackRefresh(StoredExchangeRate? stored) {
    if (stored == null) return Duration.zero;
    final elapsed = _clock().toUtc().difference(stored.sourceUpdatedAt);
    if (elapsed >= _fallbackRefreshInterval) return Duration.zero;
    if (elapsed.isNegative) return _fallbackRefreshInterval;
    return _fallbackRefreshInterval - elapsed;
  }

  Duration _fallbackDelayAfterAttempt(bool succeeded) {
    if (!succeeded) return _fallbackRetryInterval;
    final stored = _store.findUsdToRub(ExchangeRateSource.exchangeRateApi);
    final remaining = _remainingUntilFallbackRefresh(stored);
    return remaining > Duration.zero ? remaining : _fallbackRetryInterval;
  }

  void _schedulePrimaryRefresh(Duration delay) {
    if (_closed) return;
    _primaryRefreshTimer?.cancel();
    _primaryRefreshTimer = Timer(delay, () async {
      await _refreshPrimarySafely();
      await _updateMode();
      _schedulePrimaryRefresh(_primaryRefreshInterval);
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
      return true;
    } on ExchangeRateException catch (error) {
      _logRefreshFailure(ExchangeRateSource.twelveData, error);
      return false;
    }
  }

  Future<bool> _refreshFallbackSafely() async {
    try {
      await _refreshFallbackRate();
      return true;
    } on ExchangeRateException catch (error) {
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
      _store.saveUsdToRub(
        source: source,
        rate: result.rate,
        sourceUpdatedAt: result.sourceUpdatedAt,
        fetchedAt: _clock().toUtc(),
      );
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
    final primary = _store.findUsdToRub(ExchangeRateSource.twelveData);
    final fallback = _store.findUsdToRub(ExchangeRateSource.exchangeRateApi);
    if (primary != null && _isPrimaryFresh(primary)) {
      return _RateSelection(_ExchangeRateMode.primary, primary);
    }
    if (fallback != null) {
      return _RateSelection(_ExchangeRateMode.fallback, fallback);
    }
    if (primary != null) {
      return _RateSelection(_ExchangeRateMode.emergencyPrimary, primary);
    }
    throw const ExchangeRateException(
      kind: ExchangeRateErrorKind.missingRubRate,
      message: 'No confirmed USD/RUB exchange rate is stored',
    );
  }

  bool _isPrimaryFresh(StoredExchangeRate primary) {
    return _clock().toUtc().difference(primary.fetchedAt) <= _primaryMaximumAge;
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
      await _applyMode(_selectRate());
    } on ExchangeRateException catch (error) {
      if (error.kind == ExchangeRateErrorKind.missingRubRate) {
        BotLog.error('exchange_rate no_confirmed_rate pair=USD_RUB');
        return;
      }
      rethrow;
    }
  }

  Future<void> _applyMode(_RateSelection selection) async {
    final previous = _lastMode;
    if (previous == selection.mode) return;
    _lastMode = selection.mode;

    switch (selection.mode) {
      case _ExchangeRateMode.primary:
        if (previous != null && previous != _ExchangeRateMode.primary) {
          await _notifier.notifyPrimaryRestored(selection.rate);
        }
      case _ExchangeRateMode.fallback:
        await _notifier.notifyFallbackActivated(
          fallback: selection.rate,
          primary: _store.findUsdToRub(ExchangeRateSource.twelveData),
        );
      case _ExchangeRateMode.emergencyPrimary:
        await _notifier.notifyEmergencyRateActivated(selection.rate);
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
  }

  void _logStartupProviderResult({
    required ExchangeRateSource source,
    required bool succeeded,
  }) {
    final stored = _store.findUsdToRub(source);
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

  void close() {
    _closed = true;
    _primaryRefreshTimer?.cancel();
    _fallbackRefreshTimer?.cancel();
    _primaryRefreshTimer = null;
    _fallbackRefreshTimer = null;
    _twelveDataHttpClient.close();
    _exchangeRateApiHttpClient.close();
  }
}

enum _ExchangeRateMode { primary, fallback, emergencyPrimary }

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

void _validateUsdAmount(double amount) {
  if (!amount.isFinite || amount <= 0) {
    throw const ExchangeRateException(
      kind: ExchangeRateErrorKind.invalidAmount,
      message: 'USD amount must be a positive finite number',
    );
  }
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
