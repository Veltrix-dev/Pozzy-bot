import 'package:pozzy_bot/database/models/referral_stats.dart';
import 'package:pozzy_bot/database/models/user.dart';
import 'package:pozzy_bot/database/models/usd_amount.dart';
import 'package:pozzy_bot/database/repositories/referral_repository.dart';
import 'package:pozzy_bot/database/repositories/user_repositories.dart';
import 'package:pozzy_bot/services/referral/referral_notification_service.dart';

class ReferralService {
  ReferralService({
    required ReferralRepository repo,
    required UserRepositories users,
    required String botUsername,
    ReferralNotificationService? notifications,
  }) : _repo = repo,
       _users = users,
       _botUsername = botUsername,
       _notifications = notifications;

  final ReferralRepository _repo;
  final UserRepositories _users;
  final String _botUsername;
  final ReferralNotificationService? _notifications;

  static const startPayloadPrefix = 'ref_';

  static String? parseReferralCodeFromStartPayload(String payload) {
    if (!payload.startsWith(startPayloadPrefix)) return null;
    final code = payload.substring(startPayloadPrefix.length).trim();
    if (code.isEmpty || code.length > 32) return null;
    if (!RegExp(r'^[A-Za-z0-9]+$').hasMatch(code)) return null;
    return code.toUpperCase();
  }

  Future<ReferralRegisterResult> registerReferral({
    required int referralTelegramId,
    String? referralUsername,
    required String referralCode,
  }) async {
    final result = _repo.tryRegisterReferral(
      referralTelegramId: referralTelegramId,
      referralCode: referralCode,
    );
    if (result.isSuccess && result.referrerTelegramId != null) {
      await _notifications?.notifyNewReferral(
        referrerTelegramId: result.referrerTelegramId!,
        referralTelegramId: referralTelegramId,
        referralUsername: referralUsername,
      );
    }
    return result;
  }

  Future<ReferralPurchaseCommissionResult?> creditPurchaseCommission({
    required int referralTelegramId,
    required String purchaseId,
    required double purchaseAmount,
  }) async {
    final result = _repo.tryCreditPurchaseCommission(
      referralTelegramId: referralTelegramId,
      purchaseId: purchaseId,
      purchaseAmount: purchaseAmount,
    );
    if (result != null && result.wasCredited) {
      await _notifications?.notifyPurchaseCommission(result);
    }
    return result;
  }

  Future<ReferralPurchaseCommissionResult?> creditPurchaseCommissionExact({
    required int referralTelegramId,
    required String purchaseId,
    required UsdAmount purchaseAmount,
  }) async {
    final result = _repo.tryCreditPurchaseCommissionExact(
      referralTelegramId: referralTelegramId,
      purchaseId: purchaseId,
      purchaseAmount: purchaseAmount,
    );
    if (result != null && result.wasCredited) {
      await _notifications?.notifyPurchaseCommission(result);
    }
    return result;
  }

  ReferralStats statsForUser(User user) {
    return _repo.statsForReferrer(user.telegramId);
  }

  String buildReferralLink(User user) {
    final username = _botUsername.trim();
    if (username.isEmpty) {
      return 'https://t.me/?start=$startPayloadPrefix${user.referralCode}';
    }
    return 'https://t.me/$username?start=$startPayloadPrefix${user.referralCode}';
  }

  User? findByReferralCode(String referralCode) {
    return _users.findByReferralCode(referralCode);
  }
}
