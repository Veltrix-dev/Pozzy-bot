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
  });

  
  final int invitedCount;
  final double commissionTotal;
  final List<ReferralEntry> referrals;
}

class ReferralPurchaseCommissionResult {
  ReferralPurchaseCommissionResult({
    required this.referrerTelegramId,
    required this.referralTelegramId,
    required this.purchaseAmount,
    required this.commissionAmount,
  });

  final int referrerTelegramId;
  final int referralTelegramId;
  final double purchaseAmount;
  final double commissionAmount;
}

enum ReferralRegisterOutcome {
  success,
  referrerNotFound,
  selfReferral,
  alreadyReferred,
}

class ReferralRegisterResult {
   ReferralRegisterResult({
    required this.outcome,
    this.referrerTelegramId,
  });

  final ReferralRegisterOutcome outcome;
  final int? referrerTelegramId;

  bool get isSuccess => outcome == ReferralRegisterOutcome.success;   
}



