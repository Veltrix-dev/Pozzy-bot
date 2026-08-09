import 'package:pozzy_bot/database/models/referral_stats.dart';
import 'package:pozzy_bot/database/models/user.dart';
import 'package:pozzy_bot/database/repositories/referral_repository.dart';
import 'package:pozzy_bot/database/repositories/user_repositories.dart';

class ReferralService {
  ReferralService({
    required ReferralRepository repo,
    required UserRepositories users,
    required String botUsername,
  }) : _repo = repo,
       _users = users,
       _botUsername = botUsername;

  final ReferralRepository _repo;
  final UserRepositories _users;
  final String _botUsername;

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
    required String referralCode,
  }) async {
    return _repo.tryRegisterReferral(
      referralTelegramId: referralTelegramId,
      referralCode: referralCode,
    );
  }

  ReferralPurchaseCommissionResult? creditPurchaseCommission({
    required int referralTelegramId,
    required String purchaseId,
    required double purchaseAmount,
  }) {
    return _repo.tryCreditPurchaseCommission(
      referralTelegramId: referralTelegramId,
      purchaseId: purchaseId,
      purchaseAmount: purchaseAmount,
    );
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
