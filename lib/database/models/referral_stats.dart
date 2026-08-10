class ReferralEntry {
  ReferralEntry({
    required this.telegramId,
    required this.username,
    required this.joinedAt,
    required this.commissionAmount,
  });

  final int telegramId;
  final String? username;
  final DateTime joinedAt;
  final double commissionAmount;
}

class ReferralStats {
  ReferralStats({
    required this.invitedCount,
    required this.commissionTotal,
    required this.referrals,
    this.registrationCoinsEarned = 0,
  });

  final int invitedCount;
  final double commissionTotal;
  final List<ReferralEntry> referrals;
  final double registrationCoinsEarned;
}

class ReferralPurchaseCommissionResult {
  ReferralPurchaseCommissionResult({
    required this.referrerTelegramId,
    required this.referralTelegramId,
    required this.purchaseAmount,
    required this.commissionAmount,
    required this.wasCredited,
  });

  final int referrerTelegramId;
  final int referralTelegramId;
  final double purchaseAmount;
  final double commissionAmount;
  final bool wasCredited;
}

enum ReferralRegisterOutcome {
  success,
  referrerNotFound,
  selfReferral,
  alreadyReferred,
}

class ReferralRegisterResult {
  ReferralRegisterResult({required this.outcome, this.referrerTelegramId});

  final ReferralRegisterOutcome outcome;
  final int? referrerTelegramId;

  bool get isSuccess => outcome == ReferralRegisterOutcome.success;
}
