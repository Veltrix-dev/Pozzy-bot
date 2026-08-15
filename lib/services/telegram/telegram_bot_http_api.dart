import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:pozzy_bot/config/config.dart';
import 'package:pozzy_bot/utils/bot_log.dart';

class TelegramRichMessageResult {
  const TelegramRichMessageResult({
    required this.ok,
    this.errorCode,
    this.errorDescription,
  });

  final bool ok;
  final int? errorCode;
  final String? errorDescription;
}

class TelegramBotHttpApi {
  TelegramBotHttpApi({
    http.Client? client,
    String? botToken,
    this.requestTimeout = const Duration(seconds: 15),
  }) : _client = client ?? http.Client(),
       _botTokenOverride = botToken;

  final http.Client _client;
  final String? _botTokenOverride;
  final Duration requestTimeout;

  String get _botToken => (_botTokenOverride ?? Config.botToken).trim();

  Future<TelegramRichMessageResult?> sendRichMessage({
    required int chatId,
    String? html,
    String? markdown,
    bool skipEntityDetection = false,
    int? messageThreadId,
  }) async {
    final richMessage = _buildInputRichMessage(
      html: html,
      markdown: markdown,
      skipEntityDetection: skipEntityDetection,
    );
    if (richMessage == null) {
      return const TelegramRichMessageResult(
        ok: false,
        errorDescription: 'rich_message: html or markdown required',
      );
    }

    final body = <String, dynamic>{
      'chat_id': chatId,
      'rich_message': richMessage,
    };
    if (messageThreadId != null) {
      body['message_thread_id'] = messageThreadId;
    }

    return _postRichMethod('sendRichMessage', body);
  }

  Future<TelegramRichMessageResult?> sendRichMessageDraft({
    required int chatId,
    required int draftId,
    String? html,
    String? markdown,
    bool skipEntityDetection = false,
    int? messageThreadId,
  }) async {
    if (draftId == 0) {
      return const TelegramRichMessageResult(
        ok: false,
        errorDescription: 'draft_id must be non-zero',
      );
    }

    final richMessage = _buildInputRichMessage(
      html: html,
      markdown: markdown,
      skipEntityDetection: skipEntityDetection,
    );
    if (richMessage == null) {
      return const TelegramRichMessageResult(
        ok: false,
        errorDescription: 'rich_message: html or markdown required',
      );
    }

    final body = <String, dynamic>{
      'chat_id': chatId,
      'draft_id': draftId,
      'rich_message': richMessage,
    };
    if (messageThreadId != null) {
      body['message_thread_id'] = messageThreadId;
    }

    return _postRichMethod('sendRichMessageDraft', body);
  }

  Map<String, dynamic>? _buildInputRichMessage({
    String? html,
    String? markdown,
    bool skipEntityDetection = false,
  }) {
    final hasHtml = html != null && html.isNotEmpty;
    final hasMarkdown = markdown != null && markdown.isNotEmpty;
    if (hasHtml == hasMarkdown) return null;

    final richMessage = <String, dynamic>{
      if (hasHtml) 'html': html,
      if (hasMarkdown) 'markdown': markdown,
      if (skipEntityDetection) 'skip_entity_detection': true,
    };
    return richMessage;
  }

  Future<TelegramRichMessageResult> sendPhoto({
    required int chatId,
    required String fileId,
    String? caption,
    String? parseMode,
    Map<String, dynamic>? replyMarkup,
  }) {
    final body = <String, dynamic>{
      'chat_id': chatId,
      'photo': fileId,
      if (caption != null && caption.isNotEmpty) 'caption': caption,
      if (parseMode != null && parseMode.isNotEmpty) 'parse_mode': parseMode,
      if (replyMarkup != null) 'reply_markup': replyMarkup,
    };
    return _postJsonMethod('sendPhoto', body);
  }

  Future<TelegramRichMessageResult?> copyMessage({
    required int chatId,
    required int fromChatId,
    required int messageId,
  }) {
    final body = <String, dynamic>{
      'chat_id': chatId,
      'from_chat_id': fromChatId,
      'message_id': messageId,
    };
    return _postJsonMethod('copyMessage', body);
  }

  Future<TelegramRichMessageResult?> _postRichMethod(
    String method,
    Map<String, dynamic> body,
  ) => _postJsonMethod(method, body);

  Future<TelegramRichMessageResult> _postJsonMethod(
    String method,
    Map<String, dynamic> body,
  ) async {
    final token = _botToken;
    if (token.isEmpty) {
      return const TelegramRichMessageResult(
        ok: false,
        errorDescription: 'BOT_TOKEN is empty',
      );
    }
    try {
      final payload = jsonEncode(body);
      final response = await _client
          .post(
            Uri.parse('https://api.telegram.org/bot$token/$method'),
            headers: const {'Content-Type': 'application/json; charset=utf-8'},
            body: payload,
            encoding: utf8,
          )
          .timeout(requestTimeout);

      if (response.statusCode != 200) {
        final message =
            '$method http=${response.statusCode} body=${response.body}';
        BotLog.event(message);
        return TelegramRichMessageResult(ok: false, errorDescription: message);
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return const TelegramRichMessageResult(
          ok: false,
          errorDescription: 'invalid api response',
        );
      }

      final ok = decoded['ok'] == true;
      if (!ok) {
        final errorCode = decoded['error_code'] as int?;
        final description = decoded['description'] as String?;
        BotLog.event('$method api_error code=$errorCode desc=$description');
        return TelegramRichMessageResult(
          ok: false,
          errorCode: errorCode,
          errorDescription: description,
        );
      }

      return const TelegramRichMessageResult(ok: true);
    } catch (e, st) {
      BotLog.event('$method exception=$e');
      if (BotLog.verbose) {
        BotLog.debug(st.toString());
      }
      return TelegramRichMessageResult(
        ok: false,
        errorDescription: e.toString(),
      );
    }
  }
}
