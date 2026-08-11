import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:pozzy_bot/database/models/fragment_purchase_type.dart';
import 'package:pozzy_bot/database/models/ton_amount.dart';
import 'package:pozzy_bot/services/fragment/fragment_api_exception.dart';
import 'package:pozzy_bot/services/fragment/fragment_api_models.dart';
import 'package:pozzy_bot/services/fragment/fragment_gateway.dart';
import 'package:pozzy_bot/utils/bot_log.dart';

class FragmentApiClient implements FragmentGateway {
  FragmentApiClient({
    required Uri baseUri,
    required List<String> walletSeedWords,
    http.Client? httpClient,
    Duration timeout = const Duration(seconds: 120),
  }) : _baseUri = _validateBaseUri(baseUri),
       _walletSeedWords = List.unmodifiable(walletSeedWords),
       _httpClient = httpClient ?? http.Client(),
       _timeout = timeout;

  final Uri _baseUri;
  final List<String> _walletSeedWords;
  final http.Client _httpClient;
  final Duration _timeout;

  @override
  Future<FragmentApiHealth> getHealth() async {
    final response = await _request(
      method: 'GET',
      path: '/api/status',
      replaySafe: true,
    );
    final cookie = response.payload['cookie'];
    if (cookie is! Map<String, dynamic>) {
      throw const FragmentApiException(
        kind: FragmentApiErrorKind.malformedResponse,
        message: 'Fragment status response has no cookie state',
      );
    }
    return FragmentApiHealth(
      healthy: response.payload['status'] == 'healthy',
      version: _requiredString(response.payload, 'version'),
      cookieExists: cookie['exists'] == true,
      cookieValid: cookie['valid'] == true,
    );
  }

  @override
  Future<FragmentRecipient> searchUser(String username) async {
    final normalized = _normalizeUsername(username);
    final response = await _request(
      method: 'POST',
      path: '/api/search-user',
      body: jsonEncode({'username': normalized}),
      replaySafe: true,
    );
    final data = _requiredData(response.payload);
    return FragmentRecipient(
      name: _requiredString(data, 'name'),
      username: _requiredString(data, 'username'),
      photoUrl: _optionalString(data['photo']),
      recipientId: _optionalString(data['recipient_id']),
    );
  }

  @override
  Future<FragmentPurchaseReceipt> buyStars({
    required String recipient,
    required int amount,
  }) async {
    _requireWalletSeed();
    final response = await _request(
      method: 'POST',
      path: '/api/buy-stars',
      body: jsonEncode({
        'recipient': _normalizeUsername(recipient),
        'wallet_seed': _walletSeedWords,
        'amount': amount,
      }),
      replaySafe: false,
    );
    final data = _requiredData(response.payload, executionUncertain: true);
    final delivered = data['star_purchased'] ?? data['stars_purchased'];
    return _receipt(
      FragmentPurchaseType.stars,
      data,
      deliveredUnits: _requiredIntValue(
        delivered,
        'star_purchased',
        executionUncertain: true,
      ),
    );
  }

  @override
  Future<FragmentPurchaseReceipt> buyPremium({
    required String recipient,
    required int months,
  }) async {
    _requireWalletSeed();
    final response = await _request(
      method: 'POST',
      path: '/api/premium',
      body: jsonEncode({
        'recipient': _normalizeUsername(recipient),
        'wallet_seed': _walletSeedWords,
        'months': months,
      }),
      replaySafe: false,
    );
    final data = _requiredData(response.payload, executionUncertain: true);
    return _receipt(
      FragmentPurchaseType.premium,
      data,
      deliveredUnits: _requiredIntValue(
        data['months'],
        'months',
        executionUncertain: true,
      ),
    );
  }

  @override
  Future<FragmentPurchaseReceipt> addTon({
    required String recipient,
    required TonAmount amount,
  }) async {
    _requireWalletSeed();
    final marker = '__fragment_exact_amount__';
    final encoded = jsonEncode({
      'recipient': _normalizeUsername(recipient),
      'wallet_seed': _walletSeedWords,
      'amount': marker,
    }).replaceFirst('"$marker"', amount.toDecimalString());
    final response = await _request(
      method: 'POST',
      path: '/api/add-ton',
      body: encoded,
      replaySafe: false,
    );
    final data = _requiredData(response.payload, executionUncertain: true);
    final delivered = _requiredTon(
      data['amount_requested'],
      'amount_requested',
      executionUncertain: true,
    );
    return _receipt(
      FragmentPurchaseType.ton,
      data,
      deliveredUnits: delivered.nano,
    );
  }

  Future<_FragmentResponse> _request({
    required String method,
    required String path,
    String? body,
    required bool replaySafe,
  }) async {
    final uri = _baseUri.resolve(path);
    final maxAttempts = replaySafe ? 2 : 1;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      BotLog.debug(
        'fragment request path=$path attempt=$attempt replay_safe=$replaySafe',
      );
      try {
        final response = method == 'GET'
            ? await _httpClient.get(uri).timeout(_timeout)
            : await _httpClient
                  .post(
                    uri,
                    headers: const {'Content-Type': 'application/json'},
                    body: body,
                  )
                  .timeout(_timeout);
        if (response.statusCode >= 500 && attempt < maxAttempts) {
          continue;
        }
        return _decodeResponse(
          response,
          path: path,
          executionUncertain: !replaySafe,
        );
      } on TimeoutException catch (error) {
        if (attempt < maxAttempts) continue;
        throw FragmentApiException(
          kind: FragmentApiErrorKind.timeout,
          message: 'Fragment API request timed out: $error',
          executionUncertain: !replaySafe,
        );
      } on SocketException catch (error) {
        if (attempt < maxAttempts) continue;
        throw FragmentApiException(
          kind: FragmentApiErrorKind.network,
          message: 'Fragment API network error: ${error.message}',
          executionUncertain: !replaySafe,
        );
      } on http.ClientException catch (error) {
        if (attempt < maxAttempts) continue;
        throw FragmentApiException(
          kind: FragmentApiErrorKind.network,
          message: 'Fragment API client error: ${error.message}',
          executionUncertain: !replaySafe,
        );
      } on FragmentApiException {
        rethrow;
      } catch (error) {
        throw FragmentApiException(
          kind: FragmentApiErrorKind.network,
          message: 'Fragment API transport error: $error',
          executionUncertain: !replaySafe,
        );
      }
    }
    throw StateError('Unreachable Fragment API request state');
  }

  _FragmentResponse _decodeResponse(
    http.Response response, {
    required String path,
    required bool executionUncertain,
  }) {
    Map<String, dynamic> payload;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Root JSON value is not an object');
      }
      payload = decoded;
    } on FormatException catch (error) {
      throw FragmentApiException(
        kind: FragmentApiErrorKind.malformedResponse,
        message: 'Fragment API returned invalid JSON for $path: $error',
        statusCode: response.statusCode,
        executionUncertain: executionUncertain,
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final serverError = response.statusCode >= 500;
      throw FragmentApiException(
        kind: serverError
            ? FragmentApiErrorKind.httpServer
            : FragmentApiErrorKind.httpClient,
        message: _errorMessage(payload),
        statusCode: response.statusCode,
        executionUncertain: executionUncertain && serverError,
      );
    }
    if (payload['ok'] != true) {
      throw FragmentApiException(
        kind: FragmentApiErrorKind.rejected,
        message: _errorMessage(payload),
        statusCode: response.statusCode,
        executionUncertain: false,
      );
    }
    BotLog.debug('fragment response path=$path status=${response.statusCode}');
    return _FragmentResponse(payload);
  }

  FragmentPurchaseReceipt _receipt(
    FragmentPurchaseType type,
    Map<String, dynamic> data, {
    required int deliveredUnits,
  }) {
    return FragmentPurchaseReceipt(
      purchaseType: type,
      user: _requiredString(data, 'user', executionUncertain: true),
      username: _requiredString(data, 'username', executionUncertain: true),
      tonPaid: _requiredTon(
        data['ton_paid'],
        'ton_paid',
        executionUncertain: true,
      ),
      deliveredUnits: deliveredUnits,
    );
  }

  void _requireWalletSeed() {
    if (_walletSeedWords.length != 24 ||
        _walletSeedWords.any((word) => word.trim().isEmpty)) {
      throw const FragmentApiException(
        kind: FragmentApiErrorKind.configuration,
        message: 'FRAGMENT_WALLET_SEED must contain exactly 24 words',
      );
    }
  }
}

class _FragmentResponse {
  const _FragmentResponse(this.payload);

  final Map<String, dynamic> payload;
}

Uri _validateBaseUri(Uri uri) {
  final isLoopback =
      uri.host == 'localhost' || uri.host == '127.0.0.1' || uri.host == '::1';
  if (!uri.hasScheme || (!isLoopback && uri.scheme != 'https')) {
    throw const FragmentApiException(
      kind: FragmentApiErrorKind.configuration,
      message: 'FRAGMENT_API_BASE_URL must use HTTPS',
    );
  }
  return uri.replace(path: uri.path.endsWith('/') ? uri.path : '${uri.path}/');
}

String _normalizeUsername(String username) {
  final value = username.trim();
  return value.startsWith('@') ? value.substring(1) : value;
}

Map<String, dynamic> _requiredData(
  Map<String, dynamic> payload, {
  bool executionUncertain = false,
}) {
  final data = payload['data'];
  if (data is! Map<String, dynamic>) {
    throw FragmentApiException(
      kind: FragmentApiErrorKind.malformedResponse,
      message: 'Fragment API response has no data object',
      executionUncertain: executionUncertain,
    );
  }
  return data;
}

String _requiredString(
  Map<String, dynamic> data,
  String key, {
  bool executionUncertain = false,
}) {
  final value = data[key];
  if (value is! String || value.trim().isEmpty) {
    throw FragmentApiException(
      kind: FragmentApiErrorKind.malformedResponse,
      message: 'Fragment API field $key is missing or invalid',
      executionUncertain: executionUncertain,
    );
  }
  return value.trim();
}

int _requiredIntValue(
  Object? value,
  String key, {
  bool executionUncertain = false,
}) {
  final parsed = switch (value) {
    int number => number,
    num number when number == number.roundToDouble() => number.toInt(),
    String text => int.tryParse(text),
    _ => null,
  };
  if (parsed == null || parsed <= 0) {
    throw FragmentApiException(
      kind: FragmentApiErrorKind.malformedResponse,
      message: 'Fragment API field $key is missing or invalid',
      executionUncertain: executionUncertain,
    );
  }
  return parsed;
}

TonAmount _requiredTon(
  Object? value,
  String key, {
  bool executionUncertain = false,
}) {
  try {
    final amount = TonAmount.parse(value?.toString() ?? '');
    if (amount.isZero) throw const FormatException('Zero TON');
    return amount;
  } on FormatException {
    throw FragmentApiException(
      kind: FragmentApiErrorKind.malformedResponse,
      message: 'Fragment API field $key is missing or invalid',
      executionUncertain: executionUncertain,
    );
  }
}

String? _optionalString(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

String _errorMessage(Map<String, dynamic> payload) {
  final raw = payload['message'] ?? payload['error'] ?? 'Fragment API error';
  final text = raw.toString().replaceAll(RegExp(r'[\r\n]+'), ' ').trim();
  return text.length <= 500 ? text : text.substring(0, 500);
}
