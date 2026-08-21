import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:pozzy_bot/database/models/usd_amount.dart';
import 'package:pozzy_bot/services/geckoterminal/geckoterminal_exception.dart';
import 'package:pozzy_bot/services/geckoterminal/geckoterminal_ton_price_gateway.dart';

class GeckoTerminalClient implements GeckoTerminalTonPriceGateway {
  GeckoTerminalClient({
    required Uri baseUri,
    required String network,
    required String tonTokenAddress,
    http.Client? httpClient,
    Duration timeout = const Duration(seconds: 15),
    Duration cacheTtl = const Duration(seconds: 60),
    int retryAttempts = 3,
    Duration retryBaseDelay = const Duration(milliseconds: 500),
    Duration failureCooldown = const Duration(seconds: 30),
    Future<void> Function(Duration)? delay,
    Random? random,
  }) : _baseUri = _validateBaseUri(baseUri),
       _network = network.trim(),
       _tonTokenAddress = tonTokenAddress.trim(),
       _httpClient = httpClient ?? http.Client(),
       _timeout = timeout,
       _cacheTtl = cacheTtl,
       _retryAttempts = retryAttempts,
       _retryBaseDelay = retryBaseDelay,
       _failureCooldown = failureCooldown,
       _delay = delay ?? Future<void>.delayed,
       _random = random ?? Random.secure() {
    if (_network.isEmpty || _tonTokenAddress.isEmpty) {
      throw const GeckoTerminalException(
        'TON network and token address must not be empty',
      );
    }
    if (_timeout <= Duration.zero ||
        _cacheTtl <= Duration.zero ||
        _retryBaseDelay <= Duration.zero ||
        _failureCooldown <= Duration.zero ||
        _retryAttempts < 1 ||
        _retryAttempts > 5) {
      throw const GeckoTerminalException(
        'TON price client durations and retry attempts are invalid',
      );
    }
  }

  final Uri _baseUri;
  final String _network;
  final String _tonTokenAddress;
  final http.Client _httpClient;
  final Duration _timeout;
  final Duration _cacheTtl;
  final int _retryAttempts;
  final Duration _retryBaseDelay;
  final Duration _failureCooldown;
  final Future<void> Function(Duration) _delay;
  final Random _random;

  UsdAmount? _cachedPrice;
  DateTime? _cachedUntil;
  Future<UsdAmount>? _inFlight;
  GeckoTerminalException? _lastFailure;
  DateTime? _failureCooldownUntil;

  @override
  Future<UsdAmount> getTonUsdPrice() async {
    final now = DateTime.now().toUtc();
    final cachedPrice = _cachedPrice;
    final cachedUntil = _cachedUntil;
    if (cachedPrice != null &&
        cachedUntil != null &&
        now.isBefore(cachedUntil)) {
      return cachedPrice;
    }

    final cooldownUntil = _failureCooldownUntil;
    final lastFailure = _lastFailure;
    if (cooldownUntil != null &&
        lastFailure != null &&
        now.isBefore(cooldownUntil)) {
      throw lastFailure;
    }

    final activeRequest = _inFlight;
    if (activeRequest != null) return activeRequest;

    final request = _fetchTonUsdPrice();
    _inFlight = request;
    try {
      final price = await request;
      _cachedPrice = price;
      _cachedUntil = DateTime.now().toUtc().add(_cacheTtl);
      _lastFailure = null;
      _failureCooldownUntil = null;
      return price;
    } on GeckoTerminalException catch (error) {
      _lastFailure = error;
      _failureCooldownUntil = DateTime.now().toUtc().add(_failureCooldown);
      rethrow;
    } finally {
      if (identical(_inFlight, request)) _inFlight = null;
    }
  }

  Future<UsdAmount> _fetchTonUsdPrice() async {
    final uri = _baseUri.replace(
      pathSegments: [
        ..._baseUri.pathSegments.where((segment) => segment.isNotEmpty),
        'simple',
        'networks',
        _network,
        'token_price',
        _tonTokenAddress,
      ],
    );

    final response = await _sendWithRetry(uri);

    if (response.statusCode != 200) {
      throw GeckoTerminalException(
        'TON price API returned an HTTP error',
        statusCode: response.statusCode,
      );
    }

    try {
      final payload = jsonDecode(response.body);
      if (payload is! Map<String, dynamic>) {
        throw const FormatException('Root JSON value is not an object');
      }
      final data = payload['data'];
      if (data is! Map<String, dynamic>) {
        throw const FormatException('Missing data');
      }
      final attributes = data['attributes'];
      if (attributes is! Map<String, dynamic>) {
        throw const FormatException('Missing attributes');
      }
      final tokenPrices = attributes['token_prices'];
      if (tokenPrices is! Map<String, dynamic>) {
        throw const FormatException('Missing token_prices');
      }
      final rawPrice = tokenPrices[_tonTokenAddress]?.toString().trim();
      if (rawPrice == null || rawPrice.isEmpty) {
        throw const FormatException('TON price is missing');
      }
      return _parseRoundedUsd(rawPrice);
    } on FormatException catch (error) {
      throw GeckoTerminalException('Invalid TON price response: $error');
    }
  }

  Future<http.Response> _sendWithRetry(Uri uri) async {
    GeckoTerminalException? lastFailure;
    for (var attempt = 1; attempt <= _retryAttempts; attempt++) {
      try {
        final response = await _httpClient
            .get(uri, headers: {'Accept': 'application/json;version=20230203'})
            .timeout(_timeout);
        final retryable =
            response.statusCode == 429 || response.statusCode >= 500;
        if (!retryable || attempt == _retryAttempts) return response;
        await _delay(_retryDelay(attempt, response.headers['retry-after']));
      } on TimeoutException catch (error) {
        lastFailure = GeckoTerminalException(
          'TON price request timed out: $error',
          isNetworkError: true,
        );
        if (attempt == _retryAttempts) throw lastFailure;
        await _delay(_retryDelay(attempt, null));
      } on SocketException catch (error) {
        lastFailure = GeckoTerminalException(
          'TON price network error: ${error.message}',
          isNetworkError: true,
        );
        if (attempt == _retryAttempts) throw lastFailure;
        await _delay(_retryDelay(attempt, null));
      } on http.ClientException catch (error) {
        lastFailure = GeckoTerminalException(
          'TON price client error: ${error.message}',
          isNetworkError: true,
        );
        if (attempt == _retryAttempts) throw lastFailure;
        await _delay(_retryDelay(attempt, null));
      } catch (error) {
        throw GeckoTerminalException(
          'TON price transport error: $error',
          isNetworkError: true,
        );
      }
    }
    throw lastFailure ??
        const GeckoTerminalException(
          'TON price request failed',
          isNetworkError: true,
        );
  }

  Duration _retryDelay(int attempt, String? retryAfter) {
    final retryAfterDuration = _parseRetryAfter(retryAfter);
    if (retryAfterDuration != null) return retryAfterDuration;
    final multiplier = 1 << (attempt - 1);
    final baseMilliseconds = _retryBaseDelay.inMilliseconds * multiplier;
    final jitter = _random.nextInt(baseMilliseconds ~/ 2 + 1);
    return Duration(milliseconds: baseMilliseconds + jitter);
  }
}

UsdAmount _parseRoundedUsd(String raw) {
  final match = RegExp(r'^(\d+)(?:\.(\d+))?$').firstMatch(raw.trim());
  if (match == null) {
    throw const FormatException('TON price is not a decimal number');
  }
  final whole = int.parse(match.group(1)!);
  final fraction = match.group(2) ?? '';
  final microsText = fraction.padRight(6, '0').substring(0, 6);
  var micros = whole * 1000000 + int.parse(microsText);
  if (fraction.length > 6 && int.parse(fraction[6]) >= 5) micros++;
  if (micros <= 0) {
    throw const FormatException('TON price is not a positive number');
  }
  return UsdAmount.fromMicros(micros);
}

Duration? _parseRetryAfter(String? raw) {
  if (raw == null) return null;
  final seconds = int.tryParse(raw.trim());
  if (seconds != null && seconds >= 0) {
    return Duration(seconds: min(seconds, 30));
  }
  try {
    final retryAt = HttpDate.parse(raw).toUtc();
    final difference = retryAt.difference(DateTime.now().toUtc());
    if (difference <= Duration.zero) return Duration.zero;
    return difference > const Duration(seconds: 30)
        ? const Duration(seconds: 30)
        : difference;
  } on FormatException {
    return null;
  }
}

Uri _validateBaseUri(Uri uri) {
  final isLoopback =
      uri.host == 'localhost' || uri.host == '127.0.0.1' || uri.host == '::1';
  if (!uri.hasScheme || (!isLoopback && uri.scheme != 'https')) {
    throw const GeckoTerminalException(
      'GECKOTERMINAL_API_BASE_URL must use HTTPS',
    );
  }
  return uri;
}
