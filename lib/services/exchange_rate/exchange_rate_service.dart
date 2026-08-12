import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:pozzy_bot/config/config.dart';
import 'package:pozzy_bot/services/exchange_rate/exchange_rate_exception.dart';
import 'package:pozzy_bot/utils/bot_log.dart';

class ExchangeRateService {
  ExchangeRateService({
    required String apiKey,
    Uri? baseUri,
    http.Client? httpClient,
    Duration timeout = const Duration(seconds: 15),
    Duration cacheTtl = const Duration(minutes: 10),
    DateTime Function()? clock,
  }) : _apiKey = _validateApiKey(apiKey),
       _baseUri = _validateBaseUri(
         baseUri ?? Uri.parse('https://v6.exchangerate-api.com/v6/'),
       ),
       _httpClient = httpClient ?? http.Client(),
       _timeout = _validateDuration(timeout, 'timeout'),
       _cacheTtl = _validateDuration(cacheTtl, 'cacheTtl'),
       _clock = clock ?? DateTime.now;

  factory ExchangeRateService.fromConfig({
    http.Client? httpClient,
    DateTime Function()? clock,
  }) {
    return ExchangeRateService(
      apiKey: Config.exchangeRateApiKey,
      httpClient: httpClient,
      timeout: Duration(seconds: Config.exchangeRateApiTimeoutSeconds),
      cacheTtl: Duration(seconds: Config.exchangeRateCacheSeconds),
      clock: clock,
    );
  }

  final String _apiKey;
  final Uri _baseUri;
  final http.Client _httpClient;
  final Duration _timeout;
  final Duration _cacheTtl;
  final DateTime Function() _clock;

  double? _cachedUsdToRubRate;
  DateTime? _cacheExpiresAt;
  Future<double>? _inFlightRateRequest;

  Future<double> convertUsdToRub(double usdAmount) async {
    _validateUsdAmount(usdAmount);
    BotLog.debug('currency_conversion requested pair=USD_RUB');

    final rate = await _getUsdToRubRate();
    final rubAmount = usdAmount * rate;
    if (!rubAmount.isFinite || rubAmount <= 0) {
      throw const ExchangeRateException(
        kind: ExchangeRateErrorKind.invalidAmount,
        message: 'USD amount is outside the supported numeric range',
      );
    }

    BotLog.debug('currency_conversion completed pair=USD_RUB');
    return rubAmount;
  }

  Future<double> _getUsdToRubRate() async {
    final cachedRate = _cachedUsdToRubRate;
    final expiresAt = _cacheExpiresAt;
    final now = _clock().toUtc();
    if (cachedRate != null && expiresAt != null && now.isBefore(expiresAt)) {
      BotLog.debug('exchange_rate cache_hit pair=USD_RUB');
      return cachedRate;
    }

    final activeRequest = _inFlightRateRequest;
    if (activeRequest != null) {
      BotLog.debug('exchange_rate joined_active_request pair=USD_RUB');
      return activeRequest;
    }

    final request = _fetchUsdToRubRate();
    _inFlightRateRequest = request;
    try {
      final rate = await request;
      _cachedUsdToRubRate = rate;
      _cacheExpiresAt = _clock().toUtc().add(_cacheTtl);
      return rate;
    } finally {
      _inFlightRateRequest = null;
    }
  }

  Future<double> _fetchUsdToRubRate() async {
    BotLog.debug('exchange_rate request_started pair=USD_RUB');
    try {
      final response = await _httpClient
          .get(
            _baseUri.resolve('latest/USD'),
            headers: {'Authorization': 'Bearer $_apiKey'},
          )
          .timeout(_timeout);
      final rate = _parseResponse(response);
      BotLog.debug('exchange_rate valid_rate_received pair=USD_RUB');
      return rate;
    } on TimeoutException {
      final error = const ExchangeRateException(
        kind: ExchangeRateErrorKind.timeout,
        message: 'Exchange rate request timed out',
      );
      _logFailure(error);
      throw error;
    } on SocketException {
      final error = const ExchangeRateException(
        kind: ExchangeRateErrorKind.network,
        message: 'Exchange rate API is unavailable',
      );
      _logFailure(error);
      throw error;
    } on http.ClientException {
      final error = const ExchangeRateException(
        kind: ExchangeRateErrorKind.network,
        message: 'Exchange rate HTTP request failed',
      );
      _logFailure(error);
      throw error;
    } on ExchangeRateException catch (error) {
      _logFailure(error);
      rethrow;
    } catch (_) {
      final error = const ExchangeRateException(
        kind: ExchangeRateErrorKind.unexpected,
        message: 'Unexpected exchange rate request failure',
      );
      _logFailure(error);
      throw error;
    }
  }

  double _parseResponse(http.Response response) {
    final payload = _decodePayload(response);

    if (response.statusCode != 200) {
      if (payload?['result'] == 'error') {
        throw _apiRejection(payload!, response.statusCode);
      }
      throw ExchangeRateException(
        kind: response.statusCode >= 500
            ? ExchangeRateErrorKind.httpServer
            : ExchangeRateErrorKind.httpClient,
        message: 'Exchange rate API returned an HTTP error',
        statusCode: response.statusCode,
      );
    }

    if (payload == null) {
      throw const ExchangeRateException(
        kind: ExchangeRateErrorKind.malformedResponse,
        message: 'Exchange rate API returned invalid JSON',
      );
    }

    if (payload['result'] == 'error') {
      throw _apiRejection(payload, response.statusCode);
    }
    if (payload['result'] != 'success' || payload['base_code'] != 'USD') {
      throw const ExchangeRateException(
        kind: ExchangeRateErrorKind.malformedResponse,
        message: 'Exchange rate API returned an invalid response structure',
      );
    }

    final conversionRates = payload['conversion_rates'];
    if (conversionRates is! Map<String, dynamic>) {
      throw const ExchangeRateException(
        kind: ExchangeRateErrorKind.malformedResponse,
        message: 'Exchange rate API response has no conversion rates',
      );
    }

    final rubValue = conversionRates['RUB'];
    if (rubValue == null) {
      throw const ExchangeRateException(
        kind: ExchangeRateErrorKind.missingRubRate,
        message: 'Exchange rate API response has no RUB rate',
      );
    }
    if (rubValue is! num || !rubValue.toDouble().isFinite || rubValue <= 0) {
      throw const ExchangeRateException(
        kind: ExchangeRateErrorKind.malformedResponse,
        message: 'Exchange rate API returned an invalid RUB rate',
      );
    }

    return rubValue.toDouble();
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

  ExchangeRateException _apiRejection(
    Map<String, dynamic> payload,
    int statusCode,
  ) {
    final errorType = _safeApiErrorType(payload['error-type']);
    return ExchangeRateException(
      kind: ExchangeRateErrorKind.apiRejected,
      message: 'ExchangeRate-API rejected the rate request',
      statusCode: statusCode,
      apiErrorType: errorType,
    );
  }

  void _logFailure(ExchangeRateException error) {
    BotLog.error(
      'exchange_rate request_failed kind=${error.kind.name} '
      'status=${error.statusCode ?? 'none'} '
      'api_error=${error.apiErrorType ?? 'none'}',
    );
  }
}

String _validateApiKey(String apiKey) {
  final value = apiKey.trim();
  if (value.isEmpty) {
    throw const ExchangeRateException(
      kind: ExchangeRateErrorKind.configuration,
      message: 'EXCHANGE_RATE_API_KEY is not configured',
    );
  }
  return value;
}

Uri _validateBaseUri(Uri uri) {
  final isLoopback =
      uri.host == 'localhost' || uri.host == '127.0.0.1' || uri.host == '::1';
  if (!uri.hasScheme || (!isLoopback && uri.scheme != 'https')) {
    throw const ExchangeRateException(
      kind: ExchangeRateErrorKind.configuration,
      message: 'Exchange rate API base URL must use HTTPS',
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

void _validateUsdAmount(double amount) {
  if (!amount.isFinite || amount <= 0) {
    throw const ExchangeRateException(
      kind: ExchangeRateErrorKind.invalidAmount,
      message: 'USD amount must be a positive finite number',
    );
  }
}

String _safeApiErrorType(Object? value) {
  final normalized = value
      ?.toString()
      .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '')
      .trim();
  if (normalized == null || normalized.isEmpty) return 'unknown';
  return normalized.length <= 100 ? normalized : normalized.substring(0, 100);
}
