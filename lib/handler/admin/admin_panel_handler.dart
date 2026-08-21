import 'dart:async';
import 'dart:math';

import 'package:pozzy_bot/app/labels/button/adminMenu/admin_callback.dart';
import 'package:pozzy_bot/app/labels/message/adminMenu/admin_panel_text.dart';
import 'package:pozzy_bot/app/labels/message/mainMenu/start_message.dart';
import 'package:pozzy_bot/config/config.dart';
import 'package:pozzy_bot/database/models/admin_user_snapshot.dart';
import 'package:pozzy_bot/database/models/usd_amount.dart';
import 'package:pozzy_bot/database/repositories/admin_repository.dart';
import 'package:pozzy_bot/handler/reply_handler.dart';
import 'package:pozzy_bot/keyboards/adminMenu/admin_menu_keyboard.dart';
import 'package:pozzy_bot/services/admin/admin_authorization.dart';
import 'package:pozzy_bot/services/admin/admin_session_store.dart';
import 'package:pozzy_bot/services/user_service.dart';
import 'package:pozzy_bot/utils/bot_log.dart';
import 'package:televerse/telegram.dart';
import 'package:televerse/televerse.dart';

class AdminPanelHandler {
  AdminPanelHandler({
    required ReplyHandler reply,
    required UserService users,
    required AdminAuthorization authorization,
    required AdminSessionStore sessions,
    required AdminRepository repository,
    Random? secureRandom,
  }) : _reply = reply,
       _users = users,
       _authorization = authorization,
       _sessions = sessions,
       _repository = repository,
       _random = secureRandom ?? Random.secure();

  final ReplyHandler _reply;
  final UserService _users;
  final AdminAuthorization _authorization;
  final AdminSessionStore _sessions;
  final AdminRepository _repository;
  final Random _random;

  Future<void> onAdminCommand(Context ctx) async {
    final from = ctx.from;
    if (from == null) return;
    if (ctx.chat?.type != ChatType.private) {
      await _reply.sendText(
        ctx.id,
        'Команда /admin доступна только в личном чате с ботом.',
      );
      return;
    }
    if (!_authorization.isAdmin(from.id)) {
      await _reply.sendText(ctx.id, AdminPanelText.accessDenied);
      return;
    }
    await _users.getOrCreate(telegramId: from.id, username: from.username);
    _sessions.cancel(from.id);
    await _showPanel(ctx);
  }

  Future<void> onCallback(Context ctx, String data) async {
    final from = ctx.from;
    if (from == null ||
        ctx.chat?.type != ChatType.private ||
        !_authorization.isAdmin(from.id)) {
      await ctx.answerCallbackQuery(text: AdminPanelText.accessDenied);
      return;
    }
    unawaited(ctx.answerCallbackQuery().catchError((_) => false));

    final topUpToken = AdminCallback.parseTopUpConfirmation(data);
    if (topUpToken != null) {
      await _confirmTopUp(ctx, topUpToken);
      return;
    }
    final broadcastToken = AdminCallback.parseBroadcastConfirmation(data);
    if (broadcastToken != null) {
      await _confirmBroadcast(ctx, broadcastToken);
      return;
    }

    switch (data) {
      case AdminCallback.openPanel:
        _sessions.cancel(from.id);
        await _showPanel(ctx);
      case AdminCallback.statistics:
        _sessions.cancel(from.id);
        await _reply.sendText(
          ctx.id,
          AdminPanelText.statistics(_repository.collectStatistics()),
          replyMarkup: AdminMenuKeyboard.back,
        );
      case AdminCallback.userInfo:
        _sessions.save(from.id, AdminFlowStep.awaitingUserQuery);
        await _reply.sendText(ctx.id, AdminPanelText.userQueryPrompt);
      case AdminCallback.topUpUserBalance:
        _sessions.save(from.id, AdminFlowStep.awaitingTopUpTarget);
        await _reply.sendText(ctx.id, AdminPanelText.topUpTargetPrompt);
      case AdminCallback.broadcast:
        _sessions.save(from.id, AdminFlowStep.awaitingBroadcastMessage);
        await _reply.sendText(ctx.id, AdminPanelText.broadcastPrompt);
      case AdminCallback.administrators:
        _sessions.cancel(from.id);
        await _reply.sendText(
          ctx.id,
          AdminPanelText.administrators(_authorization.adminTelegramIds),
          replyMarkup: AdminMenuKeyboard.back,
        );
      case AdminCallback.cancel:
        _sessions.cancel(from.id);
        await _showPanel(ctx);
      case AdminCallback.close:
        _sessions.cancel(from.id);
        await _reply.sendMainMenu(ctx.id, text: StartMessage.startMessage);
      default:
        await _reply.sendText(ctx.id, 'Неизвестное действие админ-панели.');
    }
  }

  Future<bool> onAnyMessage(Context ctx) async {
    final from = ctx.from;
    final message = ctx.message;
    if (from == null || message == null) return false;
    final session = _sessions.find(from.id);
    if (session == null) return false;
    if (ctx.chat?.type != ChatType.private ||
        !_authorization.isAdmin(from.id)) {
      _sessions.cancel(from.id);
      return true;
    }
    final text = message.text?.trim();
    if (text != null && text.startsWith('/')) return false;

    switch (session.step) {
      case AdminFlowStep.awaitingUserQuery:
        await _handleUserQuery(ctx, text);
      case AdminFlowStep.awaitingTopUpTarget:
        await _handleTopUpTarget(ctx, text);
      case AdminFlowStep.awaitingTopUpAmount:
        await _handleTopUpAmount(ctx, session, text);
      case AdminFlowStep.awaitingBroadcastMessage:
        await _handleBroadcastMessage(ctx);
      case AdminFlowStep.awaitingTopUpConfirmation:
      case AdminFlowStep.awaitingBroadcastConfirmation:
        await _reply.sendText(
          ctx.id,
          'Сначала подтвердите или отмените текущее действие кнопкой.',
        );
    }
    return true;
  }

  void cancelForUser(int? telegramId) {
    if (telegramId != null) _sessions.cancel(telegramId);
  }

  Future<void> _showPanel(Context ctx) {
    return _reply.sendAdminMenu(ctx.id, text: AdminPanelText.panel);
  }

  Future<void> _handleUserQuery(Context ctx, String? text) async {
    if (text == null || text.isEmpty) {
      await _reply.sendText(ctx.id, 'Отправьте Telegram ID или username.');
      return;
    }
    final snapshot = _repository.findUserSnapshot(text);
    if (snapshot == null) {
      await _reply.sendText(
        ctx.id,
        'Пользователь не найден. Проверьте ID или username.',
      );
      return;
    }
    _sessions.cancel(ctx.from!.id);
    await _reply.sendText(
      ctx.id,
      AdminPanelText.userInfo(snapshot),
      replyMarkup: AdminMenuKeyboard.back,
    );
  }

  Future<void> _handleTopUpTarget(Context ctx, String? text) async {
    if (text == null || text.isEmpty) {
      await _reply.sendText(ctx.id, 'Отправьте Telegram ID или username.');
      return;
    }
    final snapshot = _repository.findUserSnapshot(text);
    if (snapshot == null) {
      await _reply.sendText(
        ctx.id,
        'Пользователь не найден. Пополнение не выполнялось.',
      );
      return;
    }
    _sessions.save(
      ctx.from!.id,
      AdminFlowStep.awaitingTopUpAmount,
      targetTelegramId: snapshot.user.telegramId,
    );
    await _reply.sendText(ctx.id, AdminPanelText.topUpAmountPrompt(snapshot));
  }

  Future<void> _handleTopUpAmount(
    Context ctx,
    AdminSession session,
    String? text,
  ) async {
    if (text == null || text.isEmpty) {
      await _reply.sendText(ctx.id, 'Отправьте сумму числом, например 10.50.');
      return;
    }
    final amount = _parseAmount(text);
    final maximum = _maximumTopUp();
    if (amount == null || amount.isZero || amount.compareTo(maximum) > 0) {
      await _reply.sendText(
        ctx.id,
        'Некорректная сумма. Допустимо больше 0 и не больше '
        '${maximum.toDecimalString()} USD, до 6 знаков после точки.',
      );
      return;
    }
    final targetTelegramId = session.targetTelegramId;
    final target = targetTelegramId == null
        ? null
        : _repository.findUserSnapshotByTelegramId(targetTelegramId);
    if (target == null) {
      _sessions.cancel(ctx.from!.id);
      await _reply.sendText(ctx.id, 'Пользователь больше не найден.');
      return;
    }
    final token = _newToken();
    _sessions.save(
      ctx.from!.id,
      AdminFlowStep.awaitingTopUpConfirmation,
      targetTelegramId: targetTelegramId,
      amount: amount,
      confirmationToken: token,
    );
    await _reply.sendText(
      ctx.id,
      AdminPanelText.topUpConfirmation(target, amount.micros),
      replyMarkup: AdminMenuKeyboard.confirmation(
        confirmCallback: '${AdminCallback.topUpConfirmPrefix}$token',
      ),
    );
  }

  Future<void> _confirmTopUp(Context ctx, String token) async {
    final adminId = ctx.from!.id;
    final session = _sessions.find(adminId);
    if (session == null ||
        session.step != AdminFlowStep.awaitingTopUpConfirmation ||
        session.confirmationToken != token ||
        session.targetTelegramId == null ||
        session.amount == null) {
      await _reply.sendText(
        ctx.id,
        'Подтверждение устарело или уже выполнено.',
      );
      return;
    }
    _sessions.cancel(adminId);
    final result = _repository.creditBalance(
      requestId: token,
      adminTelegramId: adminId,
      targetTelegramId: session.targetTelegramId!,
      amount: session.amount!,
    );
    final message = switch (result.outcome) {
      AdminCreditOutcome.applied =>
        'Баланс пополнен на ${session.amount!.toDecimalString()} USD. '
            'Новый баланс: ${UsdAmount.fromMicros(result.balanceMicros).toDecimalString()} USD.',
      AdminCreditOutcome.alreadyApplied =>
        'Эта операция уже была выполнена ранее. Повторного начисления не было.',
      AdminCreditOutcome.targetMissing =>
        'Пользователь больше не найден. Пополнение не выполнено.',
    };
    await _reply.sendText(ctx.id, message, replyMarkup: AdminMenuKeyboard.back);
  }

  Future<void> _handleBroadcastMessage(Context ctx) async {
    final message = ctx.message!;
    final token = _newToken();
    _sessions.save(
      ctx.from!.id,
      AdminFlowStep.awaitingBroadcastConfirmation,
      sourceChatId: ctx.id.id,
      sourceMessageId: message.messageId,
      confirmationToken: token,
    );
    await _reply.copyMessage(
      chatId: ctx.id.id,
      fromChatId: ctx.id.id,
      messageId: message.messageId,
    );
    await _reply.sendText(
      ctx.id,
      AdminPanelText.broadcastConfirmation(
        _repository.listAllTelegramIds().length,
      ),
      replyMarkup: AdminMenuKeyboard.confirmation(
        confirmCallback: '${AdminCallback.broadcastConfirmPrefix}$token',
      ),
    );
  }

  Future<void> _confirmBroadcast(Context ctx, String token) async {
    final adminId = ctx.from!.id;
    final session = _sessions.find(adminId);
    if (session == null ||
        session.step != AdminFlowStep.awaitingBroadcastConfirmation ||
        session.confirmationToken != token ||
        session.sourceChatId == null ||
        session.sourceMessageId == null) {
      await _reply.sendText(
        ctx.id,
        'Подтверждение устарело или уже выполнено.',
      );
      return;
    }
    _sessions.cancel(adminId);
    await _reply.sendText(ctx.id, 'Рассылка запущена.');
    var delivered = 0;
    var failed = 0;
    for (final telegramId in _repository.listAllTelegramIds()) {
      final result = await _reply.copyMessage(
        chatId: telegramId,
        fromChatId: session.sourceChatId!,
        messageId: session.sourceMessageId!,
      );
      if (result?.ok == true) {
        delivered++;
      } else {
        failed++;
      }
      final delay = Config.adminBroadcastDelayMilliseconds;
      if (delay > 0) {
        await Future<void>.delayed(Duration(milliseconds: delay));
      }
    }
    _repository.recordBroadcast(
      adminTelegramId: adminId,
      delivered: delivered,
      failed: failed,
    );
    BotLog.event(
      'admin_broadcast admin=$adminId delivered=$delivered failed=$failed',
    );
    await _reply.sendText(
      ctx.id,
      'Рассылка завершена. Доставлено: $delivered. Ошибок: $failed.',
      replyMarkup: AdminMenuKeyboard.back,
    );
  }

  UsdAmount? _parseAmount(String value) {
    try {
      return UsdAmount.parse(value.trim().replaceAll(',', '.'));
    } on FormatException {
      return null;
    }
  }

  UsdAmount _maximumTopUp() {
    try {
      final value = UsdAmount.parse(Config.adminMaximumTopUpUsdRaw);
      return value.isZero ? const UsdAmount.fromMicros(10000000000) : value;
    } on FormatException {
      return const UsdAmount.fromMicros(10000000000);
    }
  }

  String _newToken() {
    final timestamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final random = _random.nextInt(0x7fffffff).toRadixString(36);
    return '$timestamp$random';
  }
}
