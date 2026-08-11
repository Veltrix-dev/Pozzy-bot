import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:pozzy_bot/database/models/usd_amount.dart';
import 'package:pozzy_bot/services/fragment_stars_api/fragment_stars_price.dart';
import 'package:pozzy_bot/services/fragment_stars_api/fragment_stars_price_exception.dart';
import 'package:pozzy_bot/services/fragment_stars_api/fragment_stars_price_gateway.dart';
import 'package:pozzy_bot/utils/bot_log.dart';

class FragmentStarsPriceClient implements FragmentStarsPriceGateway {
  FragmentStarsPriceClient({
    required Uri baseUri,
    http.Client? httpClient,
    Duration timeout = const Duration(seconds: 30),
    Duration cacheTtl = const Duration(seconds: 60),
  }) : _baseUri = _validateBaseUri(baseUri),
       _httpClient = httpClient ?? http.Client(),
       _timeout = timeout,
       _cacheTtl = cacheTtl;

  final Uri _baseUri;
  final http.Client _httpClient;
  final Duration _timeout;
  final Duration _cacheTtl;

  FragmentStarsPrice? _cached;
  DateTime? _cachedUntil;
  Future<FragmentStarsPrice>? _inFlight;

  @override
  Future<UsdAmount> getUsdPerStar() async {
    return (await getPrices()).usdPerStar;
  }

  @override
  Future<FragmentStarsPrice> getPrices() async {
    final cached = _cached;
    final cachedUntil = _cachedUntil;
    final now = DateTime.now().toUtc();
    if (cached != null && cachedUntil != null && now.isBefore(cachedUntil)) {
      return cached;
    }

    final activeRequest = _inFlight;
    if (activeRequest != null) return activeRequest;

    final request = _fetchPrices();
    _inFlight = request;
    try {
      final prices = await request;
      _cached = prices;
      _cachedUntil = _resolveCacheExpiry(prices, now);
      return prices;
    } finally {
      _inFlight = null;
    }
  }

  Future<FragmentStarsPrice> _fetchPrices() async {
    final uri = _baseUri.resolve('/api/v1/prices');
    for (var attempt = 1; attempt <= 2; attempt++) {
      BotLog.debug('fragment_stars_price request attempt=$attempt');
      try {
        final response = await _httpClient.get(uri).timeout(_timeout);
        if (response.statusCode >= 500 && attempt == 1) continue;
        return _parseResponse(response);
      } on TimeoutException catch (error) {
        if (attempt == 1) continue;
        throw FragmentStarsPriceException(
          'Price request timed out: $error',
          isNetworkError: true,
        );
      } on SocketException catch (error) {
        if (attempt == 1) continue;
        throw FragmentStarsPriceException(
          'Price API network error: ${error.message}',
          isNetworkError: true,
        );
      } on http.ClientException catch (error) {
        if (attempt == 1) continue;
        throw FragmentStarsPriceException(
          'Price API client error: ${error.message}',
          isNetworkError: true,
        );
      } on FragmentStarsPriceException {
        rethrow;
      } catch (error) {
        throw FragmentStarsPriceException(
          'Price API transport error: $error',
          isNetworkError: true,
        );
      }
    }
    throw const FragmentStarsPriceException('Unreachable price request state');
  }

  FragmentStarsPrice _parseResponse(http.Response response) {
    if (response.statusCode != 200) {
      throw FragmentStarsPriceException(
        'Price API returned an HTTP error',
        statusCode: response.statusCode,
      );
    }

    Map<String, dynamic> payload;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Root JSON value is not an object');
      }
      payload = decoded;
    } on FormatException catch (error) {
      throw FragmentStarsPriceException('Invalid price JSON: $error');
    }

    if (payload['success'] != true) {
      throw FragmentStarsPriceException(_errorMessage(payload));
    }

    try {
      return FragmentStarsPrice.fromJson(payload);
    } on FormatException catch (error) {
      throw FragmentStarsPriceException(error.message);
    }
  }

  DateTime _resolveCacheExpiry(FragmentStarsPrice prices, DateTime fetchedAt) {
    final localExpiry = fetchedAt.add(_cacheTtl);
    final serverExpiry = prices.cacheExpiresAt;
    if (serverExpiry == null || !serverExpiry.isAfter(fetchedAt)) {
      return localExpiry;
    }
    return serverExpiry.isBefore(localExpiry) ? serverExpiry : localExpiry;
  }
}

Uri _validateBaseUri(Uri uri) {
  final isLoopback =
      uri.host == 'localhost' || uri.host == '127.0.0.1' || uri.host == '::1';
  if (!uri.hasScheme || (!isLoopback && uri.scheme != 'https')) {
    throw const FragmentStarsPriceException(
      'FRAGMENT_STARS_API_BASE_URL must use HTTPS',
    );
  }
  return uri.replace(path: uri.path.endsWith('/') ? uri.path : '${uri.path}/');
}

String _errorMessage(Map<String, dynamic> payload) {
  final raw = payload['message'] ?? payload['error'] ?? 'Stars price API error';
  final normalized = raw.toString().replaceAll(RegExp(r'[\r\n]+'), ' ').trim();
  return normalized.length <= 500 ? normalized : normalized.substring(0, 500);
}
