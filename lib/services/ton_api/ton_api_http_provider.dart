import 'dart:async';
import 'dart:convert';

import 'package:blockchain_utils/service/service.dart';
import 'package:http/http.dart' as http;
import 'package:pozzy_bot/services/ton_api/ton_api_exception.dart';
import 'package:ton_dart/ton_dart.dart';

class TonApiHttpProvider implements TonServiceProvider {
  TonApiHttpProvider({
    required this.baseUrl,
    required this.apiKey,
    required this.requestTimeout,
    required this.minimumRequestInterval,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final String apiKey;
  final Duration requestTimeout;
  final Duration minimumRequestInterval;
  final http.Client _client;

  DateTime? _lastRequestAt;
  Future<void> _requestChain = Future<void>.value();

  @override
  final TonApiType api = TonApiType.tonApi;

  @override
  Future<BaseServiceResponse<T>> doRequest<T>(
    TonRequestDetails params, {
    Duration? timeout,
  }) async {
    await _waitForTurn();
    final uri = params.toUri(baseUrl);
    final headers = <String, String>{
      ...params.headers,
      'Authorization': 'Bearer $apiKey',
      'Accept': 'application/json',
    };
    final effectiveTimeout = timeout ?? requestTimeout;
    if (params.type.isPostRequest) {
      final response = await _client
          .post(uri, headers: headers, body: params.body())
          .timeout(effectiveTimeout);
      _validateStatus(response);
      return params.parseResponse(response.bodyBytes, response.statusCode);
    }
    final response = await _client
        .get(uri, headers: headers)
        .timeout(effectiveTimeout);
    _validateStatus(response);
    return params.parseResponse(response.bodyBytes, response.statusCode);
  }

  void _validateStatus(http.Response response) {
    final status = response.statusCode;
    if (status >= 200 && status < 300) return;
    final kind = status == 401 || status == 403
        ? TonApiErrorKind.unauthorized
        : status == 429
        ? TonApiErrorKind.rateLimit
        : status >= 500
        ? TonApiErrorKind.server
        : TonApiErrorKind.rejected;
    throw TonApiException(
      kind: kind,
      message: _errorMessage(response),
      statusCode: status,
    );
  }

  String _errorMessage(http.Response response) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) {
        final value = decoded['error'];
        if (value is String && value.trim().isNotEmpty) {
          return value.trim();
        }
      }
    } catch (_) {}
    return 'TON API request failed with HTTP ${response.statusCode}';
  }

  Future<void> _waitForTurn() {
    final completer = Completer<void>();
    final previous = _requestChain;
    _requestChain = completer.future;
    unawaited(
      previous.then((_) async {
        final lastRequestAt = _lastRequestAt;
        if (lastRequestAt != null) {
          final remaining =
              minimumRequestInterval - DateTime.now().difference(lastRequestAt);
          if (remaining > Duration.zero) {
            await Future<void>.delayed(remaining);
          }
        }
        _lastRequestAt = DateTime.now();
        completer.complete();
      }, onError: completer.completeError),
    );
    return completer.future;
  }

  void close() => _client.close();
}
