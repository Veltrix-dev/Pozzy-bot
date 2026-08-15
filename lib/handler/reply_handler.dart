import 'dart:io' as io;

import 'package:pozzy_bot/keyboards/mainMenu/main_menu_keyboards.dart';
import 'package:pozzy_bot/services/telegram/menu_photo_key.dart';
import 'package:pozzy_bot/services/telegram/menu_photo_service.dart';
import 'package:pozzy_bot/services/telegram/rich_message_html.dart';
import 'package:pozzy_bot/services/telegram/telegram_bot_http_api.dart';
import 'package:pozzy_bot/utils/bot_log.dart';
import 'package:televerse/telegram.dart';
import 'package:televerse/televerse.dart';

class ReplyHandler {
  ReplyHandler(
    this._bot, {
    MenuPhotoService? menuPhotos,
    TelegramBotHttpApi? botHttp,
  }) : _menuPhotos = menuPhotos,
       _botHttp = botHttp ?? TelegramBotHttpApi();

  final Bot<Context> _bot;
  final MenuPhotoService? _menuPhotos;
  final TelegramBotHttpApi _botHttp;

  Future<void> sendText(
    ChatID chatId,
    String text, {
    ReplyMarkup? replyMarkup,
  }) async {
    await _bot.api.sendMessage(
      chatId,
      text,
      parseMode: ParseMode.html,
      replyMarkup: replyMarkup,
      linkPreviewOptions: LinkPreviewOptions(isDisabled: false),
    );
  }

  Future<void> sendMenuWithPhoto(
    ChatID chatId, {
    required MenuPhotoKey photo,
    required String text,
    InlineKeyboardMarkup? replyMarkup,
  }) async {
    final fileId = _menuPhotos?.fileIdFor(photo)?.trim();
    if (fileId != null && fileId.isNotEmpty) {
      final result = await _botHttp.sendPhoto(
        chatId: chatId.id,
        fileId: fileId,
        caption: text,
        parseMode: 'HTML',
        replyMarkup: replyMarkup?.toJson(),
      );
      if (result.ok) return;

      if (MenuPhotoService.isInvalidFileIdError(result)) {
        BotLog.event(
          'sendPhoto stale file_id (${photo.name}), re-uploading from disk',
        );
        _menuPhotos?.clearFileId(photo);
      } else {
        BotLog.event(
          'sendPhoto failed (${photo.name}): ${result.errorDescription}',
        );
      }
    }

    final path = MenuPhotoService.resolveMediaPathFor(photo);
    if (path != null) {
      try {
        final message = await _bot.api.sendPhoto(
          chatId,
          InputFile.fromFile(io.File(path)),
          caption: text,
          parseMode: ParseMode.html,
          replyMarkup: replyMarkup,
        );
        final photos = message.photo;
        if (photos != null && photos.isNotEmpty) {
          _menuPhotos?.cacheFileId(
            photo,
            photos.last.fileId,
            sourceFileName: MenuPhotoService.sourceFileNameFromPath(path),
          );
        }
        return;
      } catch (e, st) {
        BotLog.event('sendPhoto upload failed (${photo.name}): $e\n$st');
      }
    }

    await sendText(chatId, text, replyMarkup: replyMarkup);
  }

  Future<TelegramRichMessageResult?> copyMessage({
    required int chatId,
    required int fromChatId,
    required int messageId,
  }) {
    return _botHttp.copyMessage(
      chatId: chatId,
      fromChatId: fromChatId,
      messageId: messageId,
    );
  }

  Future<TelegramRichMessageResult?> sendRichMessage(
    ChatID chatId, {
    String? html,
    String? markdown,
    bool skipEntityDetection = false,
  }) {
    return _botHttp.sendRichMessage(
      chatId: chatId.id,
      html: html,
      markdown: markdown,
      skipEntityDetection: skipEntityDetection,
    );
  }

  Future<TelegramRichMessageResult?> sendRichMessageDraft(
    ChatID chatId, {
    required int draftId,
    String? html,
    String? markdown,
    bool skipEntityDetection = false,
  }) {
    return _botHttp.sendRichMessageDraft(
      chatId: chatId.id,
      draftId: draftId,
      html: html,
      markdown: markdown,
      skipEntityDetection: skipEntityDetection,
    );
  }

  Future<TelegramRichMessageResult?> sendRichMessageWithDraft(
    ChatID chatId, {
    required String draftHtml,
    required Future<String> Function() buildContent,
    bool useMarkdown = true,
    bool skipEntityDetection = false,
  }) async {
    final draftId = chatId.id;
    if (draftId == 0) {
      return const TelegramRichMessageResult(
        ok: false,
        errorDescription: 'chat id is zero',
      );
    }

    final draftResult = await sendRichMessageDraft(
      chatId,
      draftId: draftId,
      html: draftHtml,
    );
    if (!draftResult!.ok) {
      BotLog.event(
        'sendRichMessageDraft failed: ${draftResult.errorDescription}',
      );
    }

    final content = await buildContent();
    if (useMarkdown) {
      return sendRichMessage(
        chatId,
        markdown: content,
        skipEntityDetection: skipEntityDetection,
      );
    }
    return sendRichMessage(
      chatId,
      html: content,
      skipEntityDetection: skipEntityDetection,
    );
  }

  Future<void> sendProcessingStatus(
    ChatID chatId,
    String statusText, {
    int? draftId,
  }) async {
    final chatIdValue = chatId.id;
    final result = await _botHttp.sendRichMessageDraft(
      chatId: chatIdValue,
      draftId: draftId ?? chatIdValue,
      html: RichMessageHtml.thinking(statusText),
    );
    if (result?.ok != true) {
      await sendText(chatId, statusText);
    }
  }

  Future<void> sendMainMenu(ChatID chatId, {required String text}) async {
    await sendMenuWithPhoto(
      chatId,
      photo: MenuPhotoKey.mainMenu,
      text: text,
      replyMarkup: MainMenuKeyboards().markup,
    );
  }

  Future<void> answerCallback(Context ctx) async {
    await ctx.answerCallbackQuery();
  }
}
