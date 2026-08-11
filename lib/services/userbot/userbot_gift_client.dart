import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:pozzy_bot/config/config.dart';
import 'package:pozzy_bot/services/userbot/userbot_gift_result.dart';
import 'package:pozzy_bot/utils/bot_log.dart';

abstract interface class GiftDeliveryClient {
  Future<bool> isHealthy();

  Future<UserbotGiftResult> sendGift({
    required String giftId,
    required String recipient,
    String? message,
    bool hideName = true,
  });
}

class UserbotGiftClient implements GiftDeliveryClient {
  String get _baseUrl =>
      Config.userbotApiBaseUrl.replaceAll(RegExp(r'/+$'), '');

  Map<String, String> get _headers {
    final headers = <String, String>{'Content-Type': 'application/json'};
    final secret = Config.userbotApiSecret;
    if (secret.isNotEmpty) {
      headers['X-Userbot-Secret'] = secret;
    }
    return headers;
  }

  @override
  Future<bool> isHealthy() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/health'), headers: _headers)
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return false;
      return _decodeBody(response.body)['ok'] == true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<UserbotGiftResult> sendGift({
    required String giftId,
    required String recipient,
    String? message,
    bool hideName = true,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/send-gift'),
            headers: _headers,
            body: jsonEncode({
              'gift_id': giftId,
              'recipient': recipient,
              'message': ?message,
              'hide_name': hideName,
            }),
          )
          .timeout(const Duration(seconds: 60));

      final payload = _decodeBody(response.body);
      if (response.statusCode == 401) {
        return UserbotGiftResult.failure(
          error: UserbotGiftError.userbotNotConnected,
          detail: 'Userbot API unauthorized',
        );
      }
      if (response.statusCode != 200) {
        return UserbotGiftResult.failure(
          error: UserbotGiftError.unknown,
          detail: 'HTTP ${response.statusCode}: $payload',
        );
      }
      if (payload['success'] == true) {
        final realGiftId = payload['real_gift_id'];
        return UserbotGiftResult.success(
          realGiftId: realGiftId is int
              ? realGiftId
              : int.tryParse('$realGiftId'),
        );
      }
      return _mapError(payload);
    } on TimeoutException catch (error) {
      BotLog.error('userbot send-gift timeout: $error');
      return UserbotGiftResult.failure(
        error: UserbotGiftError.timeout,
        detail: error.toString(),
      );
    } catch (error) {
      BotLog.error('userbot send-gift request failed: $error');
      return UserbotGiftResult.failure(
        error: UserbotGiftError.unknown,
        detail: error.toString(),
      );
    }
  }

  Map<String, dynamic> _decodeBody(String body) {
    if (body.isEmpty) return const {};
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return {'detail': body};
  }

  UserbotGiftResult _mapError(Map<String, dynamic> payload) {
    final code = (payload['error'] as String?)?.toUpperCase() ?? 'UNKNOWN';
    final waitSeconds = payload['wait_seconds'];
    final error = switch (code) {
      'USERBOT_NOT_CONNECTED' => UserbotGiftError.userbotNotConnected,
      'GIFT_ID_NOT_FOUND' => UserbotGiftError.giftIdNotFound,
      'BALANCE_TOO_LOW' => UserbotGiftError.balanceTooLow,
      'PEER_ID_INVALID' => UserbotGiftError.peerIdInvalid,
      'USERNAME_INVALID' => UserbotGiftError.usernameInvalid,
      'STARGIFT_USAGE_LIMITED' => UserbotGiftError.stargiftUsageLimited,
      'STARGIFT_INVALID' => UserbotGiftError.stargiftInvalid,
      'FLOOD_WAIT' => UserbotGiftError.floodWait,
      _ => UserbotGiftError.unknown,
    };
    return UserbotGiftResult.failure(
      error: error,
      detail: payload['detail'] as String?,
      waitSeconds: waitSeconds is int
          ? waitSeconds
          : int.tryParse('$waitSeconds'),
    );
  }
}
