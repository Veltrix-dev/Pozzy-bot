import 'package:pozzy_bot/database/models/usd_amount.dart';

enum AdminFlowStep {
  awaitingUserQuery,
  awaitingTopUpTarget,
  awaitingTopUpAmount,
  awaitingTopUpConfirmation,
  awaitingBroadcastMessage,
  awaitingBroadcastConfirmation,
}

class AdminSession {
  const AdminSession({
    required this.step,
    required this.expiresAt,
    this.targetTelegramId,
    this.amount,
    this.sourceChatId,
    this.sourceMessageId,
    this.confirmationToken,
  });

  final AdminFlowStep step;
  final DateTime expiresAt;
  final int? targetTelegramId;
  final UsdAmount? amount;
  final int? sourceChatId;
  final int? sourceMessageId;
  final String? confirmationToken;
}

class AdminSessionStore {
  AdminSessionStore({required Duration ttl, DateTime Function()? now})
    : _ttl = ttl,
      _now = now ?? DateTime.now;

  final Duration _ttl;
  final DateTime Function() _now;
  final Map<int, AdminSession> _sessions = {};

  AdminSession? find(int adminTelegramId) {
    final session = _sessions[adminTelegramId];
    if (session == null) return null;
    if (!_now().isBefore(session.expiresAt)) {
      _sessions.remove(adminTelegramId);
      return null;
    }
    return session;
  }

  void save(
    int adminTelegramId,
    AdminFlowStep step, {
    int? targetTelegramId,
    UsdAmount? amount,
    int? sourceChatId,
    int? sourceMessageId,
    String? confirmationToken,
  }) {
    _sessions[adminTelegramId] = AdminSession(
      step: step,
      expiresAt: _now().add(_ttl),
      targetTelegramId: targetTelegramId,
      amount: amount,
      sourceChatId: sourceChatId,
      sourceMessageId: sourceMessageId,
      confirmationToken: confirmationToken,
    );
  }

  void cancel(int adminTelegramId) {
    _sessions.remove(adminTelegramId);
  }
}
